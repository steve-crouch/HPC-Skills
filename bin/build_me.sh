#!/usr/bin/env bash

# Developer note: This is a local build file that broadly replicates the processes in the .github/workflows/website.yml
#                 if you are editing this file to make a local build work then the corresponding changes must be made in
#                 the github workflow.

case "$OSTYPE" in
  solaris*) echo "OS SOLARIS not supported"; exit ;;
  darwin*)  MYOS="OSX" ;;
  linux*)   MYOS="LINUX" ;;
  bsd*)     echo "OS BSD not supported"; exit ;;
  msys*)    echo "OS WINDOWS not supported"; exit ;;
  cygwin*)  echo "OS WINDOWS not supported"; exit ;;
  *)        exit ;;
esac

if [ "$MYOS" = "LINUX" ]; then
  read -p "Please provide package manager: " MYPKGMGR
  sudo $MYPKGMGR install -y libcurl4-openssl-dev python3 python3-pip ruby ruby-dev libxml2
  curl -sSL https://get.rvm.io | bash -s stable
  source ~/.bashrc
fi;

if [ "$MYOS" = "OSX" ]; then
  read -p "Please confirm use of homebrew y/n: " HBOK
  if [ "$HBOK" != "y" ]; then
    exit
  fi
  brew install curl
  brew install xml2
  brew install ruby
  brew install --cask jewelrybox
fi

# Make a branch to build on to avoid messing up main
MYBRANCH=$(git rev-parse --abbrev-ref HEAD)
git branch -d localbuild || echo 'branch local build does not exist to delete'
git checkout -b localbuild

# Replicate GH actions
python -m venv ./venv || echo 'venv already exists'

#TODO: Make this windows safe
source venv/bin/activate

rvm install 2.7.1
rvm use 2.7.1
#TODO: Check why we need sudo here on ubuntu
gem install github-pages bundler kramdown kramdown-parser-gfm

#TODO: Make this platform safe
# sudo apt-get install -y libcurl4-openssl-dev

python3 -m pip install --upgrade pip setuptools wheel pyyaml==5.3.1 requests
python3 -m pip install -r requirements.txt

python bin/get_submodules.py

if ls _episodes_rmd/*.Rmd >/dev/null 2>&1; then
  Rscript renv/activate.R
  script -e 'renv::restore()'
  RMD_PATH=$(find ./_episodes_rmd -name '*.Rmd')
  Rscript -e 'for (f in commandArgs(TRUE)) if (file.exists(f)) rmarkdown::render(f, knit_root_dir=getwd(), output_dir=dirname(sub("./_episodes_rmd/", "./_episodes/", f)))' ${RMD_PATH[*]}
  perl -pi -e "s/([>\s]*)(>\s)(.*?)(\{: \.[a-zA-Z]+\})/\1\2\3\n\1\4\n\1/g" ./_episodes/*.md
  perl -0777pi -e "s/(?<!\n){: .challenge}/\n{: .challenge}/g" ./_episodes/*.md
fi

python bin/make_favicons.py
python bin/get_schedules.py
python bin/get_setup.py

# Build the site.
bundle install
bundle exec jekyll serve --baseurl=""
# All GH actions replicated

#Note: the site is up here and will remain up until an interrupt (ctrl-c) is sent then the resto of this script triggers
#      and cleans out the build.

# Clean the things not tracked by git (Local Only: not replicated on GH actions)
rm setup.md
rm -r _site/ venv/ collections/ fig/ _includes/rsg/*-lesson/ slides/ _includes/ submodules/
find -f ./data \! -name "*.md" -depth 1 -delete
rm assets/favicons/rsg/apple* assets/favicons/rsg/favicon* assets/favicons/rsg/mstile*
if ls _episodes_rmd/*.Rmd >/dev/null 2>&1; then
  rm _episodes/*.md _episodes/_page_built_on.html
  rm -r _episodes_rmd/fig/
  # These files are created in r-novice day 3
  rm combo_plot_abun_weight.png name_of_file.png
fi
z
# Checkout main and cleanup branch
git checkout $MYBRANCH
git branch -d localbuild || echo 'branch local build does not exist to delete'