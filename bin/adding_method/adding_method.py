"""
This is command line script to create method module files from template


Usage:
  adding_method.py [options]

Options:
  --method=METHOD             Name of the method
  --language=LANG             Language used to implement the method
  --outdir=OUTDIR             Output directory 
  --docker_user=DOCKER_USER   User of the dockerhub to retrieve image from
  --force_update              Force to rewrite/update existing method contents from template [default: False]
"""

from docopt import docopt
from messi_add_method.create_method import MethodCreate
import sys
# ABOVE is the main class
def main(method, language, outdir, docker_user, force_update):
    """
    Add new method into MESSI using provided template.

    Uses provided template to make a skeleton Nextflow pipeline with all required
    files, boilerplate code and best-practices.
    """
    try:
        create_obj = MethodCreate(
            method=method,
            language=language,
            outdir=outdir,
            docker_user=docker_user,
            force_update=force_update
        )
        # Create method relevant files
        create_obj.init_method()
    except UserWarning as e:
        # log.error(e)
        print(e)
        sys.exit(1)


# Call the main function here with cli options
if __name__ == "__main__":
    # Parse cli options
    args = docopt(__doc__)
    # Execute the main function
    main(
      method=args['--method'], 
      language=args['--language'],
      outdir=args['--outdir'],
      docker_user=args['--docker_user'],
      force_update=bool(args['--force_update'])
    )
