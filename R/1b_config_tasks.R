set_tasks <- function() {
  config$tasks <- TaskManager$new()

  ##############
  #### data ####
  config$tasks$add_task(
    task_from_config(
      list(
        name = "data_pre_norsyss",
        type = "data",
        action = "data_pre_norsyss",
        schema = list(),
        args = list(
          date_from = "2014-01-01"
        )
      )
    )
  )

  config$tasks$add_task(
    task_from_config(
      list(
        name = "data_normomo",
        type = "data",
        action = "data_normomo",
        schema = list(output = config$schema$datar_normomo)
      )
    )
  )
  config$tasks$add_task(
    task_from_config(
      list(
        name = "data_weather",
        type = "data",
        action = "data_weather",
        schema = list(output = config$schema$data_weather)
      )
    )
  )
  config$tasks$add_task(
    task_from_config(
      list(
        name = "data_msis",
        type = "data",
        action = "data_msis",
        schema = list(output = config$schema$data_msis),
        args = list(
          start_year = 2008,
          end_year = 2019,
          tags = c("Kikoste", "Campylobacteriose")
        )
      )
    )
  )

  config$tasks$add_task(
    task_from_config(
      list(
        name = "data_norsyss",
        type = "data",
        action = "data_norsyss",
        schema = list(output = config$schema$data_norsyss),
        args = list(
          syndromes = rbind(
            data.table(
              tag_input = "influensa",
              tag_output = "influensa_lf_l",
              contactType = list("Legekontakt"),
              practice_type = list(c("Legevakt", "Fastlege"))
            ),
            data.table(
              tag_input = "influensa",
              tag_output = "influensa_lf_lt",
              contactType = list(c("Legekontakt", "Telefonkontakt")),
              practice_type = list(c("Legevakt", "Fastlege"))
            ),
            data.table(
              tag_input = "gastro",
              tag_output = "gastro_lf_lt",
              contactType = list(c("Legekontakt", "Telefonkontakt")),
              practice_type = list(c("Legevakt", "Fastlege"))
            ),
            data.table(
              tag_input = "respiratoryinternal",
              tag_output = "respiratoryinternal_lf_lt",
              contactType = list(c("Legekontakt", "Telefonkontakt")),
              practice_type = list(c("Legevakt", "Fastlege"))
            ),
            data.table(
              tag_input = "respiratoryexternal",
              tag_output = "respiratoryexternal_lf_lt",
              contactType = list(c("Legekontakt", "Telefonkontakt")),
              practice_type = list(c("Legevakt", "Fastlege"))
            ),

            # lte
            data.table(
              tag_input = "covid19",
              tag_output = "covid19_lf_lte",
              contactType = list(c("Legekontakt", "Telefonkontakt", "Ekonsultasjon")),
              practice_type = list(c("Legevakt", "Fastlege"))
            ),
            data.table(
              tag_input = "influensa",
              tag_output = "influensa_lf_lte",
              contactType = list(c("Legekontakt", "Telefonkontakt", "Ekonsultasjon")),
              practice_type = list(c("Legevakt", "Fastlege"))
            ),
            data.table(
              tag_input = "rxx_for_covid19",
              tag_output = "rxx_for_covid19_lf_lte",
              contactType = list(c("Legekontakt", "Telefonkontakt", "Ekonsultasjon")),
              practice_type = list(c("Legevakt", "Fastlege"))
            ),
            data.table(
              tag_input = "akkut_ovre_luftveisinfeksjon",
              tag_output = "akkut_ovre_luftveisinfeksjon_lf_lte",
              contactType = list(c("Legekontakt", "Telefonkontakt", "Ekonsultasjon")),
              practice_type = list(c("Legevakt", "Fastlege"))
            ),
            data.table(
              tag_input = "engstelig_luftveissykdom_ika",
              tag_output = "engstelig_luftveissykdom_ika_lf_lte",
              contactType = list(c("Legekontakt", "Telefonkontakt", "Ekonsultasjon")),
              practice_type = list(c("Legevakt", "Fastlege"))
            ),

            # strata
            data.table(
              tag_input = "covid19",
              tag_output = "covid19_l_l",
              contactType = list(c("Legekontakt")),
              practice_type = list(c("Legevakt"))
            ),
            data.table(
              tag_input = "covid19",
              tag_output = "covid19_l_t",
              contactType = list(c("Telefonkontakt")),
              practice_type = list(c("Legevakt"))
            ),
            data.table(
              tag_input = "covid19",
              tag_output = "covid19_l_e",
              contactType = list(c("Ekonsultasjon")),
              practice_type = list(c("Legevakt"))
            ),
            data.table(
              tag_input = "covid19",
              tag_output = "covid19_f_l",
              contactType = list(c("Legekontakt")),
              practice_type = list(c("Fastlege"))
            ),
            data.table(
              tag_input = "covid19",
              tag_output = "covid19_f_t",
              contactType = list(c("Telefonkontakt")),
              practice_type = list(c("Fastlege"))
            ),
            data.table(
              tag_input = "covid19",
              tag_output = "covid19_f_e",
              contactType = list(c("Ekonsultasjon")),
              practice_type = list(c("Fastlege"))
            )

          )
        )
      )
    )
  )

  ##################
  #### analysis ####
  config$tasks$add_task(
    Task$new(
      name = "analysis_normomo",
      type = "analysis",
      update_plans_fn = analysis_normomo_plans,
      schema = c("output" = config$schema$results_normomo_standard),
      cores = min(6, parallel::detectCores()),
      chunk_size = 1
    )
  )

  config$tasks$add_task(
    task_from_config(
      conf = list(
        name = "analysis_norsyss_qp_weekly_gastro_lf_lt",
        db_table = "data_norsyss",
        type = "analysis",
        dependencies = c("data_norsyss"),
        cores = min(7, parallel::detectCores()),
        chunk_size= 1000,
        action = "analysis_qp",
        filter = "tag_outcome=='gastro_lf_lt'",
        for_each_plan = list("age" = "all", "sex" = "Totalt"),
        for_each_argset = list("location_code" = "all"),
        schema = list(
          output = config$schema$results_norsyss_standard
        ),
        upsert_at_end_of_each_plan = TRUE,
        args = list(
          tag = "gastro_lf_lt",
          train_length = 5,
          years = c(2018, 2019, 2020),
          weeklyDenominatorFunction = sum,
          denominator = "consult_without_influenza",
          granularity_time = "weekly"
        )
      )
    )
  )
  config$tasks$add_task(
    task_from_config(
      conf = list(
        name = "analysis_norsyss_qp_daily_gastro_lf_lt",
        db_table = "data_norsyss",
        type = "analysis",
        dependencies = c("data_norsyss"),
        cores = min(6, parallel::detectCores()),
        chunk_size= 100,
        action = "analysis_qp",
        filter = "tag_outcome=='gastro_lf_lt' & (granularity_geo=='county' | granularity_geo=='national')",
        for_each_plan = list("location_code" = "all", "age" = "all", "sex" = "Totalt"),
        schema = list(
          output = config$schema$results_norsyss_standard
        ),
        upsert_at_end_of_each_plan = TRUE,
        args = list(
          tag = "gastro_lf_lt",
          train_length = 5,
          years = c(2018, 2019, 2020),
          weeklyDenominatorFunction = sum,
          denominator = "consult_without_influenza",
          granularity_time = "daily"
        )
      )
    )
  )

  config$tasks$add_task(
    task_from_config(
      conf = list(
        name = "analysis_norsyss_qp_weekly_respiratoryexternal_lf_lt",
        db_table = "data_norsyss",
        type = "analysis",
        dependencies = c("data_norsyss"),
        cores = min(7, parallel::detectCores()),
        chunk_size= 1000,
        action = "analysis_qp",
        filter = "tag_outcome=='respiratoryexternal_lf_lt'",
        for_each_plan = list("age" = "all", "sex" = "Totalt"),
        for_each_argset = list("location_code" = "all"),
        schema = list(
          output = config$schema$results_norsyss_standard
        ),
        upsert_at_end_of_each_plan = TRUE,
        args = list(
          tag = "respiratoryexternal_lf_lt",
          train_length = 5,
          years = c(2018, 2019, 2020),
          weeklyDenominatorFunction = sum,
          denominator = "consult_without_influenza",
          granularity_time = "weekly"
        )
      )
    )
  )
  config$tasks$add_task(
    task_from_config(
      conf = list(
        name = "analysis_norsyss_qp_daily_respiratoryexternal_lf_lt",
        db_table = "data_norsyss",
        type = "analysis",
        dependencies = c("data_norsyss"),
        cores = min(6, parallel::detectCores()),
        chunk_size= 100,
        action = "analysis_qp",
        filter = "tag_outcome=='respiratoryexternal_lf_lt' & (granularity_geo=='county' | granularity_geo=='national')",
        for_each_plan = list("location_code" = "all", "age" = "all", "sex" = "Totalt"),
        schema = list(
          output = config$schema$results_norsyss_standard
        ),
        upsert_at_end_of_each_plan = TRUE,
        args = list(
          tag = "respiratoryexternal_lf_lt",
          train_length = 5,
          years = c(2018, 2019, 2020),
          weeklyDenominatorFunction = sum,
          denominator = "consult_without_influenza",
          granularity_time = "daily"
        )
      )
    )
  )

  config$tasks$add_task(
    task_from_config(
      list(
        name = "analysis_norsyss_mem_influensa",
        db_table = "data_norsyss",
        type = "analysis",
        dependencies = c("data_norsyss"),
        action = "analysis_mem",
        filter = "(granularity_geo=='county' | granularity_geo=='national') & tag_outcome=='influensa'",
        for_each_plan = list("location_code" = "all"),
        schema = list(
          output = config$schema$results_mem,
          output_limits = config$schema$results_mem_limits
        ),
        args = list(
          age = jsonlite::toJSON(list("Totalt" = c("Totalt"))),
          tag = "influensa",
          weeklyDenominatorFunction = "sum",
          multiplicative_factor = 100,
          denominator = "consult_with_influenza"
        )
      )
    )
  )

  config$tasks$add_task(
    task_from_config(
      list(
        name = "analysis_norsyss_mem_influensa_all",
        db_table = "data_norsyss",
        type = "analysis",
        dependencies = c("data_norsyss"),
        action = "analysis_mem",
        filter = "(granularity_geo=='county' | granularity_geo=='norge') & tag_outcome=='influensa_all'",
        for_each_plan = list("location_code" = "all"),
        schema = list(
          output = config$schema$results_mem,
          output_limits = config$schema$results_mem_limits
        ),
        args = list(
          age = jsonlite::toJSON(list(
            "0-4" = c("0-4"), "5-14" = c("5-14"),
            "15-64" = c("15-19", "20-29", "30-64"), "65+" = c("65+")
          )),
          tag = "influensa",
          weeklyDenominatorFunction = "sum",
          multiplicative_factor = 100,
          denominator = "consult_with_influenza"
        )
      )
    )
  )

  config$tasks$add_task(
    task_from_config(
      list(
        name = "analysis_simple_msis",
        type = "analysis",
        db_table = "data_msis",
        action = "analysis_simple",
        dependencies = c("data_msis"),
        schema = list(output = config$schema$results_simple),
        for_each_plan = list("location_code" = "all", "tag_outcome" = c("Kikoste", "Campylobacteriose")),
        args = list(
          group_by = "month",
          past_years = 5
        )
      )
    )
  )

  ############
  #### ui ####
  config$tasks$add_task(
    task_from_config(
      list(
        name = "ui_threshold_plot_msis",
        type = "ui",
        action = "ui_create_threshold_plot",
        db_table = "results_simple",
        schema = NULL,
        for_each_plan = list("location_code" = "all", "tag_outcome" = c("Kikoste", "Campylobacteriose")),
        dependencies = c("norsyss_mem_influensa"),
        args = list(
          filename = "{location_code}.png",
          folder = " {tag_outcome}/{today}"
        ),
        filter = "year > 2010 & source == 'data_msis'"
      )
    )
  )

  config$tasks$add_task(
    task_from_config(
      list(
        name = "ui_norsyss_mem_influensa",
        type = "ui",
        action = "ui_mem_plots",
        db_table = "results_mem",
        schema = NULL,
        for_each_plan = list(tag_outcome = c("influensa_all")),
        dependencies = c("norsyss_mem_influensa_all"),
        args = list(
          tag = "influensa",
          icpc2 = "R60",
          contactType = "Legekontakt, Telefonkontakt",
          folder_name = "mem_influensa",
          outputs = c("n_doctors_sheet")
        ),
        filter = "source=='data_norsyss'"
      )
    )
  )

  config$tasks$add_task(
    task_from_config(
      list(
        name = "ui_norsyss_mem_influensa_all",
        type = "ui",
        action = "ui_mem_plots",
        db_table = "results_mem",
        schema = NULL,
        for_each_plan = list(tag_outcome = c("influensa")),
        dependencies = c("simple_analysis_msis"),
        args = list(
          tag = "influensa",
          icpc2 = "R80",
          contactType = "Legekontakt",
          folder_name = "mem_influensa",
          outputs = c("charts", "county_sheet", "region_sheet", "norway_sheet")
        ),
        filter = "source=='data_norsyss'"
      )
    )
  )

  config$tasks$add_task(
    task_from_config(
      list(
        name = "ui_external_api",
        type = "data",
        schema=list(input=config$schema$results_norsyss_standard),
        action="ui_external_api",
        args = list(
          tags = c("gastro"),
          short = config$def$short_names[[c("gastro")]],
          long =  config$def$long_names[[c("gastro")]],
          age = config$def$age$norsyss
        )
      )
    )
  )
  config$tasks$add_task(
    task_from_config(
      list(
        name = "ui_alert_pdf",
        type = "data",
        schema=list(input=config$schema$results_norsyss_standard),
        action="ui_alert_pdf",
        args = list(
          tags = c("gastro"),
          name_short = config[["def"]]$short_names,
          name_long = config[["def"]]$long_names
        )
      )
    )
  )
  config$tasks$add_task(
    task_from_config(
      list(
        name = "ui_norsyss_pdf",
        type = "data",
        schema=list(input=config$schema$results_norsyss_standard),
        action="ui_norsyss_pdf",
        args = list(
          tags = c("gastro"),
          name_short = config[["def"]]$short_names,
          name_long = config[["def"]]$long_names
        )
      )
    )
  )
  config$tasks$add_task(
    task_from_config(
      list(
        name = "ui_archive_results_norsyss_standard",
        type = "data",
        schema=list(input=config$schema$results_norsyss_standard),
        action="ui_archive_results",
        args = list(
          folder = "norsyss_qp",
          years = 2
        )
      )
    )
  )
 config$tasks$add_task(
    task_from_config(
      list(
        name = "ui_obsmail_norsyss",
        type = "data",
        schema=list(input=config$schema$results_norsyss_standard),
        action="ui_obsmail",
        args = list(
          folder = "norsyss_qp",
          tags = c("gastro")
        )
      )
    )
  )

 config$tasks$add_task(
   task_from_config(
     list(
       name = "ui_normomo_ssi",
       type = "single",
       action = "ui_normomo_ssi",
       schema = list(input=config$schema$results_normomo_standard),
       dependencies = c("results_normomo_standard"),
       args = list(
         filename = "{tag}_{location_code}_{age}_{yrwk_minus_1}.png",
         folder = "normomo/{today}/graphs_status"
       )
     )
   )
 )

 config$tasks$add_task(
   task_from_config(
     list(
       name = "ui_normomo_thresholds_1yr_5yr",
       type = "ui",
       action = "ui_normomo_thresholds_1yr_5yr",
       db_table = "results_normomo_standard",
       schema = list(input=config$schema$results_normomo_standard),
       for_each_plan = list("location_code" = "all", "age" = "all"),
       dependencies = c("results_normomo_standard"),
       args = list(
         filename = "{tag}_{location_code}_{age}_{yrwk_minus_1}.png",
         folder = "normomo/{today}/graphs_thresholds"
       )
     )
   )
 )

 p <- plnr::Plan$new(use_foreach=T)
 for(i in 1:30){
   p$add_analysis(fn = function(data, argset, schema){Sys.sleep(1)})
 }
 config$tasks$add_task(
   Task$new(
     name = "test_parallel_1",
     type = "analysis",
     plans = list(p),
     schema = c("output" = config$schema$results_normomo_standard),
     cores = min(6, parallel::detectCores()),
     chunk_size = 1
   )
 )

 config$tasks$add_task(
   Task$new(
     name = "test_parallel_2",
     type = "analysis",
     plans = list(p,p),
     schema = c("output" = config$schema$results_normomo_standard),
     cores = min(6, parallel::detectCores()),
     chunk_size = 1
   )
 )

}

test_parallel <- function(data, argset, schema){

}
