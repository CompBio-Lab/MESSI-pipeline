#!/usr/bin/env python

# ============================================================================
# - The shebang line at line 1 is required
# - You need to make the script executable by: chmod +x script_name.py
# - The script should be placed under method/resource/usr/bin
# - when wring the doc for docopt, DO NOT USE tab, use spaces
# Author: Tony Liang
# ============================================================================
"""
This is a sample python script with cli arguments support
Change this script for your use and write more useful doc here

Usage:
  python_cli.py [options]

Options:
  -h --help           Show this message
  -n --number=<n>     Number to print [default: 5]
  -v --verbose        Print default message
"""
# This above is the __doc__ 
# Space matter between Usage, Options, Arguments
# Let args = docopt(__doc__)
# =============================================================================
# Usage should have the following sytanx
# name_of_file [options] <arg1> <arg2> ARG3 ...
# [options] and <argi> see below for more detailed explanation
# (-a | -b) XOR, only one of option could happen here 
# [] means optional
# () means required BY DEFAULT, all not in [] are required!
# ... one or more arguments
# [options] != [Options]
# =============================================================================
# Options could have short hand or long version, but always accessed by long 
# version for ambiguity, and could have default arg
# And usually let it to be --long_ver=<the_param_could_be_named_as_other>
# i.e. --number=<n>
# And option allows to have default argument by: 
# -p    A message of [default: something_here]
# =============================================================================
# Argument are required parameter in cli, and accessed by args["<name_arg>"]
# Or you could specify argument by all UPPER_CASE, no number in it
# Not included for now, since argument are usually required parameter,
# user might not know what to expect and include it
# =============================================================================
# When not sure what if arguments/options are parsed correctly or not
# try print(args) , where args=docopt(__doc__) to verify it
###############################################################################
# For more information on good example of docopt, see this link below
# https://www.blopig.com/blog/2018/10/docopt-for-dummies/

from docopt import docopt
def main():
    args = docopt(__doc__)
    verbose = args['--verbose']
    if verbose:
        print("Extra message")
    print(args)
    return 0
# Invoke the function here

main()