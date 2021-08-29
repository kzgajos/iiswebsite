#!/bin/sh

#ssh login.seas.harvard.edu '~/updateIisSite.sh'
rsync -avz -e ssh * kgajos@pub-aws.seas.harvard.edu:/seas/web/sites_dynamic/iis.seas.harvard.edu/htdocs/