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

if test -d /lib/systemd/system; then
    snapsync_gem=`bundler show snapsync`
    sudo cp $snapsync_gem/snapsync.service /lib/systemd/system
    ( sudo systemctl enable snapsync.service
      sudo systemctl start snapsync.service )
fi

rm -rf $target

