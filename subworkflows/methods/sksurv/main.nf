/* =========================================================================== */
/*

Survival method workflow (scikit-survival), mirrors the sklearn classification
method workflow: preprocess -> train (per fold x model) -> predict -> merge.

Author: Tony Liang
Date: 2026-09-18
*/
/* =========================================================================== */

def method_dir = "${modulesDir}/sksurv"
include { SKSURV_PREPROCESS }   from "${method_dir}/preprocess"
include { SKSURV_TRAIN }        from "${method_dir}/train"
include { SKSURV_PREDICT }      from "${method_dir}/predict"
include { MERGE_RESULT_TABLE }  from "${modulesDir}/merge_result_table"

// Workflow related params
def method_name = "sksurv"
def saveMode = "method"


workflow SKSURV {
  // Survival models to train: coxnet | rsf | gbm
  model_name  = Channel.fromList(params.survival_model_names)
  take:
  // dataset name + path of mu data + directory of fold txts
  data_copy

  main:
      // ======================================================================
      // 1. Preprocess: partition full MuData into per-fold train/test h5mu
      SKSURV_PREPROCESS ( data_copy )
      data_copy.join(  SKSURV_PREPROCESS.out.fold_splits, by:0 )
              .multiMap { it ->
                  input_data: [ it[0], it[1] ]              // [dataset_name, mu_data]
                  data_folds:  [ it[0], it[3].flatten() ]   // [fold1, fold2, ... , foldk]
                }.set{ interm }
      interm.input_data
                    .combine(interm.data_folds.transpose(), by: 0)
                    .set {  train_input }
      // ======================================================================

      /*
        2. Train for each fold; inner CV (alpha selection for coxnet) happens
           inside the training fold only.
      */
      SKSURV_TRAIN ( train_input, model_name )

      SKSURV_TRAIN.out.model
                  .join(SKSURV_TRAIN.out.test_data, by: [0, 1, 2])
                  .multiMap { it ->
                    model:      [ it[0], it[1], it[2], it[3] ] // [ dataset_name, fold_name, model_name, model ]
                    test_data:  [ it[0], it[1], it[2], it[4] ] // [ dataset_name, fold_name, model_name, test_data]
                  }.set { predict_input }
      // ======================================================================

      /*
        3. Predict per fold: per-observation risk score (lp) + S(t) horizons.
      */
      SKSURV_PREDICT (
        predict_input.model,
        predict_input.test_data,
        Channel.value(method_name)
        )
      // ======================================================================

      /*
        4. Collect results of predicted folds and merge.
      */
      SKSURV_PREDICT.out.result_table
                    .groupTuple(by: 2)
                    .map {it ->
                      [ it[2], it[3] ]
                    }
                    .set { result_table }
      MERGE_RESULT_TABLE ( result_table, saveMode, params.outcome_type )
      // =====================================================================

    emit:
      csv_results = MERGE_RESULT_TABLE.out.csv_results
}
