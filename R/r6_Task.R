data_function_factory <- function(table_name, filter){
  force(table_name)
  force(filter)
  function() {
    if (is.na(filter)) {
      d <- tbl(table_name) %>%
        dplyr::collect() %>%
        latin1_to_utf8()
    } else {
      d <- tbl(table_name) %>%
        dplyr::filter(!!!rlang::parse_exprs(filter)) %>%
        dplyr::collect() %>%
        latin1_to_utf8()
    }
  }
}

get_filters <- function(for_each, table_name, filter=""){
  retval <- list()
  for (t in names(for_each)) {
    message(glue::glue("{Sys.time()} Starting pulling plan data for {t} from {table_name}"))
    if (for_each[t] == "all") {
      table <- tbl(table_name)
      if (filter != "") {
        table <- table %>% dplyr::filter(!!!rlang::parse_exprs(filter))
      }
      options <- table %>%
        dplyr::distinct(!!as.symbol(t)) %>%
        dplyr::collect() %>%
        dplyr::pull(!!as.symbol(t))
    } else {
      options <- for_each[[t]]
    }
    retval[[t]] <- options
    message(glue::glue("{Sys.time()} Finished pulling plan data for {t} from {table_name}"))
  }
  return(retval)
}

#' task_from_config
#'
#' @export
task_from_config <- function(conf) {
  name <- conf$name
  plans <- list()
  schema <- conf$schema
  cores <- get_list(conf, "cores", 1)
  chunk_size <- get_list(conf, "chunk_size", 1)
  task <- NULL
  if (conf$type %in% c("data","single")) {
    plan <- plnr::Plan$new()
    arguments <- list(
      fn = get(conf$action),
      name = name,
      today=Sys.Date()
    )
    if ("args" %in% names(conf)) {
      arguments <- c(arguments, conf$args)
    }
    do.call(plan$add_analysis, arguments)

    task <- Task$new(
      name = name,
      type = conf$type,
      plans = list(plan),
      schema = schema,
      dependencies = get_list(conf, "dependencies", c()),
      cores = cores,
      chunk_size = chunk_size,
      upsert_at_end_of_each_plan = get_list(conf, "upsert_at_end_of_each_plan", FALSE)
    )
  } else if (conf$type %in% c("analysis", "ui")) {
    task <- Task$new(
      name = name,
      type = conf$type,
      plans = plans,
      schema = schema,
      dependencies = get_list(conf, "dependencies", c()),
      cores = cores,
      chunk_size = chunk_size,
      upsert_at_end_of_each_plan = get_list(conf, "upsert_at_end_of_each_plan", FALSE)
    )

    task$update_plans_fn <- function() {
      table_name <- conf$db_table
      x_plans <- list()

      filters_plan <- get_filters(
        for_each = conf$for_each_plan,
        table_name = table_name,
        filter = get_list(conf, "filter", default = "")
      )
      filters_argset <- get_filters(
        for_each = conf$for_each_argset,
        table_name = table_name,
        filter = get_list(conf, "filter", default = "")
      )

      filters_plan <- do.call(tidyr::crossing, filters_plan)
      filters_argset <- do.call(tidyr::crossing, filters_argset)

      for (i in 1:nrow(filters_plan)) {
        current_plan <- plnr::Plan$new()
        fs <- c()
        arguments <- list(
          fn = get(conf$action), name = glue::glue("{name}_{i}"),
          source_table = table_name,
          today = Sys.Date()
        )
        for (n in names(filters_plan)) {
          arguments[n] <- filters_plan[i, n]
          fs <- c(fs, glue::glue("{n}=='{filters_plan[i,n]}'"))
        }
        extra_filter <- get_list(conf, "filter", default = "")

        filter <- paste(fs, collapse = " & ")
        if (extra_filter != "") {
          filter <- paste(filter, extra_filter, sep = " & ")
        }
        current_plan$add_data(name = "data", fn = data_function_factory(table_name, filter))

        if ("args" %in% names(conf)) {
          arguments <- c(arguments, conf$args)
        }

        if(nrow(filters_argset)==0){
          do.call(current_plan$add_analysis, arguments)
        } else {
          for(j in 1:nrow(filters_argset)){
            for (n in names(filters_argset)) {
              arguments[n] <- filters_argset[j, n]
            }
            arguments$name <- glue::glue("{arguments$name}_{j}")
            do.call(current_plan$add_analysis, arguments)
          }
        }
        x_plans[[i]] <- current_plan
      }
      return(x_plans)
    }
  }
  return(task)
}

#' Task
#'
#' @import R6
#' @import foreach
#' @export
Task <- R6::R6Class(
  "Task",
  portable = FALSE,
  cloneable = TRUE,
  public = list(
    type = NULL,
    plans = list(),
    schema = list(),
    dependencies = list(),
    cores = 1,
    chunk_size = 100,
    upsert_at_end_of_each_plan = FALSE,
    name = NULL,
    update_plans_fn = NULL,
    initialize = function(
      name,
      type,
      plans=NULL,
      update_plans_fn=NULL,
      schema,
      dependencies = c(),
      cores = 1,
      chunk_size = 100,
      upsert_at_end_of_each_plan = FALSE
      ) {
      self$name <- name
      self$type <- type
      self$plans <- plans
      self$update_plans_fn <- update_plans_fn
      self$schema <- schema
      self$cores <- cores
      self$dependencies <- dependencies
      self$chunk_size <- chunk_size
      self$upsert_at_end_of_each_plan <- upsert_at_end_of_each_plan
    },
    update_plans = function() {
      if (!is.null(self$update_plans_fn)) {
        message(glue::glue("Updating plans..."))
        self$plans <- self$update_plans_fn()
      }
    },
    num_argsets = function() {
      retval <- 0
      for (i in seq_along(plans)) {
        retval <- retval + plans[[i]]$len()
      }
      return(retval)
    },
    run = function(log = TRUE, cores = self$cores) {
      # task <- tm_get_task("analysis_norsyss_qp_gastro")

      message(glue::glue("task: {self$name}"))

      upsert_at_end_of_each_plan <- self$upsert_at_end_of_each_plan

      if (log == FALSE | can_run()) {
        self$update_plans()

        # progressr::with_progress({
        #   pb <- progressr::progressor(steps = self$num_argsets())
        #   for (i in seq_along(plans)) {
        #     if(!interactive()) print(i)
        #     plans[[i]]$set_progress(pb)
        #     plans[[i]]$run_all(schema = schema)
        #   }
        # })

        message(glue::glue("Running task={self$name} with plans={length(self$plans)} and argsets={self$num_argsets()}"))

        if(cores != 1){
          doFuture::registerDoFuture()

          if(length(self$plans)==1){
            # parallelize the inner loop
            future::plan(list(
              future::sequential,
              future::multisession,
              workers = cores,
              earlySignal = TRUE
            ))

            parallel <- "plans=sequential, argset=multisession"
          } else {
            # parallelize the outer loop
            future::plan(future::multisession, workers = cores)

            parallel <- "plans=multisession, argset=sequential"
          }
        } else {
          data.table::setDTthreads()

          parallel <- "plans=sequential, argset=sequential"
        }

        message(glue::glue("{parallel} with cores={cores} and chunk_size={self$chunk_size}"))

        if(cores == 1){
          # not running in parallel
          pb <- progress::progress_bar$new(
            format = "[:bar] :current/:total (:percent) in :elapsedfull, eta: :eta",
            clear = FALSE,
            total = self$num_argsets()
          )
          for(s in schema) s$db_connect()
          for(x in self$plans){
            x$set_progress(pb)
            retval <- x$run_all(schema = schema)
            if(upsert_at_end_of_each_plan){
              retval <- rbindlist(retval)
              schema$output$db_upsert_load_data_infile(retval, verbose=F)
            }
            rm("retval")
          }
          for(s in schema) s$db_disconnect()

        } else {
          # running in parallel
          message("\n***** REMEMBER TO INSTALL SYKDOMSPULSEN *****")
          message("***** OR ELSE THE PARALLEL PROCESSES WON'T HAVE ACCESS *****")
          message("***** TO THE NECESSARY FUNCTIONS *****\n")

          progressr::with_progress(
            {
              pb <- progressr::progressor(steps = self$num_argsets())
              y <- foreach(x = self$plans) %dopar% {
                data.table::setDTthreads(1)

                for(s in schema) s$db_connect()
                x$set_progressor(pb)
                retval <- x$run_all(schema = schema)
                if(upsert_at_end_of_each_plan){
                  retval <- rbindlist(retval)
                  schema$output$db_upsert_load_data_infile(retval, verbose=F)
                }
                rm("retval")
                for(s in schema) s$db_disconnect()

                #################################
                # NEVER DELETE gc()             #
                # IT CAUSES 2x SPEEDUP          #
                # AND 10x MEMORY EFFICIENCY     #
                gc()                            #
                #################################
                1
              }
            },
            delay_stdout=FALSE,
            delay_conditions = ""
          )
        }

        future::plan(future::sequential)
        foreach::registerDoSEQ()
        data.table::setDTthreads()

        if (log) {
          update_rundate(
            task = self$name,
            date_run = lubridate::today()
          )
        }
      } else {
        print(glue::glue("Not running {self$name}"))
      }
    },
    can_run = function() {
      rundates <- get_rundate(task=self$name)
      if(nrow(rundates) > 0){
        last_run_date <- max(rundates$date_run)
      } else{
        last_run_date <- as.Date("2000-01-01")
      }
      curr_date <- lubridate::today()
      dependencies <- c()
      if(curr_date <= last_run_date){
        return(FALSE)
      }

      for(dependency in self$dependencies){
        dep_run_date <- get_rundate(task=dependency)
        if(nrow(dep_run_date) == 0){
          return(FALSE)
        }else if(last_run_date >= max(dep_run_date$date_run)){
            return(FALSE)
        }
      }


      return(TRUE)
    }
  )
)
