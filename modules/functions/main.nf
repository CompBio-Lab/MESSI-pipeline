// Function to parse process name of within method to get the shorthand alias instead
/*
Ex: cv_r/diablo/diablo_preprocess --> cv_r/diablo/preprocess
    cv_python/special-method_abc/special-method_abc_preprocess --> cv_python/special-method_abc/preprocess
*/

def getPublishPath(String process_name) {
  // so cv_r:diablo:diablo_preprocess to [cv_r, diablo, diablo_preprocess]
  def parts = process_name.tokenize(":")
  // only modifying last element of parts
  def tail  = parts.removeLast().tokenize('_').last()
  // append this modified tail back and return it
  return (parts << tail).join('/').toLowerCase()
}


// Fun to handle as many directories of MAE
def parseDataDirs(list_paths) {
  // Should parse many path in the list that contains MAE
  mae_paths = Channel.fromList(list_paths)
                      .map { it -> 
                        file("${it}/**/*mae*/", type: 'dir')
                      }
                      .flatten()
                      .map { it ->
                        [it.parent.name, it]
                      }
  mu_paths = Channel.fromList(list_paths)
                      .map { it -> 
                        file("${it}/**/*.h5mu", type: 'file')
                      }
                      .flatten()
                      .map { it ->
                        [it.parent.name, it]
                      }
  return [mae_paths, mu_paths]
}

/*
  Calculate a unique seed for every dataset
*/
def calculateSeed(String dataset_name) {
    def seed = Math.abs(dataset_name.hashCode())
    def seedLength = seed.toString().length()
    // Define modulo value based on half the number of digits
    def moduloValue = Math.min(Math.pow(10, seedLength / 2) as int, 2147483647)
    return seed % moduloValue
}



/* 
  Create the combination parameters to use in simulation
  Default only varies numbers and number of predictors
*/
def createSimCombination(params) {
  def dNum 	= 0 // Init this as 0 to be identifier of dataset
  /* 
    Assign to simpler list when running in simpler grid, 
    otherwise use those in config/params.config
  */
  def num_obs         = (params.runSimple) ? [50, 100]  : params.num_obs
  def num_predictors  = (params.runSimple) ? [200]      : params.num_predictors
  def block_num       = (params.runSimple) ? [3]        : params.block_num
  ch_sim_params_comb = Channel.fromList(num_obs)
    .combine(Channel.fromList(num_predictors))
    .combine(Channel.fromList(block_num))
    .combine(Channel.fromList(params.latent_predictors))
    .combine(Channel.fromList(params.sigma))
    .combine(Channel.fromList(params.sy))
    .combine(Channel.fromList(params.sp))
    .combine(Channel.fromList(params.u_std))
    .combine(Channel.fromList(params.fct_str))
    .combine(Channel.fromList(params.task))
    .combine(Channel.fromList(params.tr))
    .combine(Channel.of(params.dataset_base_name))
    .combine(Channel.of(params.y_name))
    .map { num, np, block_n, lat_p, sigma, sy, sp, u_std, fct_str, task, tr, base_name, y_name -> 
          dNum++ // Increment the sample number
          [
            dataset_name: "${base_name}${dNum}", 
            num_obs: num,
            num_predictors: np,
            block_num: block_n,
            latent_predictors: lat_p,
            sigma: sigma,
            sy: sy,
            sp: sp,
            u_std: u_std,
            fct_str: fct_str,
            task: task,
            tr: tr,
            y_name: y_name,
            seed: calculateSeed("${base_name}${dNum}")
          ] // Map with key-value pair
    }
    .flatten()
    return ch_sim_params_comb
  }


// use this print separator between messages
def printBanner(character="=", n=80) {
  log.info "\n${character * n}\n"
}