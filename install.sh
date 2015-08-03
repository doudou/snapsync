#! /bin/sh -ex

target=`mktemp -d`
cd $target
cat > Gemfile <<GEMFILE
source "https://rubygems.org"
gem 'snapsync'
GEMFILE

bundler install --standalone --binstubs
if test -d /opt/snapsync; then
    sudo rm -rf /opt/snapsync
    sudo cp -r . /opt/snapsync
fi

rm -rf $target

        
