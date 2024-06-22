// This looks very hard-coded, TODO: fix this later and improve it
def method_name = "sgmr"

workflow SGMR {
  take:
    mae_copy
  main:
  // TODO: This method is still boilerplate
    log.info "This is SGMR method name: ${method_name}"
  emit:
    csv_results = Channel.empty()
}