// Include all relevant modules of a method

include { TRAIN_GOAT }  from "$modulesDir/goat"
//include { PREPROCESS_METHOD_NAME } from "$modulesDir/preprocess_method_name"

// TODO: this is still a template
workflow GOAT {
  take:
    mu_copy
  main:
    // Might have some preprocessing steps
    //(prep_data, prep_name, ... ) = PREPROCESS_METHOD_NAME ( dataset, name )

  emit:
    csv_results = Channel.empty()
}
