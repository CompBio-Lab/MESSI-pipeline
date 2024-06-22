
/*
  This part is to show reading each data format in, joing them together, and make it into map

*/
params.test_data = 'data/minimal_test'
mae_ch = Channel.fromPath( "${params.test_data}/**/*mae*" , type: 'dir' )
                .map{[it.getSimpleName().split("_mae_data")[0], it]}
mu_ch = Channel.fromPath( "${params.test_data}/**/*.h5mu", type: 'file' )
                .map{[it.getSimpleName(), it]}
ch_data = mae_ch.join(mu_ch)

ch_data.map {
  it -> [name: it[0], mae: it[1], mu: it[2]]
}.subscribe {
  println """
  ${it.name}
  ${it.mae.getSimpleName()}
  ${it.mu.getName()}
  """.stripIndent()
}

// This should work if the input is ch_data above
process DUMMY {
	input:
		tuple val(id), path(mae_path), path(mu_path)
	exec:
	println "This is id ${id}"
	println "This is mae path: ${mae_path}"
	println "This is mu path: ${mu_path}"
}
