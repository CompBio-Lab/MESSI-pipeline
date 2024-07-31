workflow {
    lmh_list = ["low", "med", "high"]
    n_list = [50, 100, 500]
    effect_list = lmh_list
    sigma_list = ["def", "indep"]
    corr_list = [0, 0.5 , 1]
    Channel.fromList(n_list)
           .combine(Channel.fromList(effect_list))
           .combine(Channel.fromList(sigma_list))
           .combine(Channel.fromList(corr_list))
           // Make this into a map
           .map { number, effect, sigma, corr -> [ n: number, effect: effect, s: sigma, rho: corr] }
           .set { grid_comb }
    
    grid_comb.count().view()
    grid_comb.view()
}