DEBFULLNAME="EF DevOps"
DEBEMAIL="devops@edgeflip.com"
BUILDS_DIR=/mnt/builds
REPO_DIR=/mnt/packages
export WORKON_HOME=$DEST_DIR/.virtualenvs
eval `dpkg-architecture -s`

check_args() {
    if [ -n "$1" ]
    then
        TAG="$1"
    else
        echo "No valid tag supplied"
        echo "Usage: $0 gitTag debVersion"
        exit 1
    fi

    if [ -n "$2" ]
    then
        VERSION="$2"
    else
        VERSION=`echo ${TAG} | sed 's/v//g'`
    fi
}

clone_app() {
    if [ -d $DEST_DIR ]
    then
        rm -rf $DEST_DIR
    fi
    git clone --recursive $REPODIR $DEST_DIR
}

checkout_tag() {
    git checkout $TAG
    git describe
    git submodule init && git submodule update
}

clean_git() {
    rm -rf .git .gitignore README*
}

add_appinfo() {
    echo "{\"version\": \"$TAG\"}" > app_info.json
}

build_python_noreqs() {
    virtualenv .
    source bin/activate
    rm -rf local
    python -m compileall .
    deactivate
}

build_python() {
    virtualenv --distribute .
    cp /var/www/edgeflip/edgeflip.pth /var/www/edgeflip/lib/python2.7/site-packages/
    source bin/activate
    pip install distribute
    pip install -r $REQUIREMENTS
    rm -rf local
    python -m compileall .
    deactivate
}

build_python_celery() {
    virtualenv --distribute .
    cp /var/www/edgeflipcelery/edgeflip.pth /var/www/edgeflipcelery/lib/python2.7/site-packages/
    source bin/activate
    pip install distribute
    pip install -r $REQUIREMENTS
    /var/www/edgeflipcelery/bin/python /var/www/edgeflipcelery/setup.py develop
    rm -rf local
    python -m compileall .
    deactivate
}

build_python_app() {
    virtualenv --distribute .
    source bin/activate
    pip install distribute==0.7.3 -U
    pip install -r $REQUIREMENTS
    rm -rf local
    mkdir /var/www/edgeflip/conf.d
    /var/www/edgeflip/bin/python /var/www/edgeflip/manage.py collectstatic --noinput
    /var/www/edgeflip/bin/python /var/www/edgeflip/manage.py jsurls install --all-profiles --minify --noinput
    python -m compileall .
    deactivate
}
build_php() {
    echo "building php packages is easy"
}

fix_perms() {
    find . -type d -exec chmod 0750 {} \;
    find . -type f -exec chmod 0640 {} \;
}

build_ruby() {
    if [ -n $RUBY_VERSION ]
    then
        echo "${RUBY_VERSION}" > .rbenv-version
    fi
    bundle install --without development test
    bundle install --deployment --without development test
    #echo "Precompiling assets:"
    #RAILS_ENV=production bundle exec rake assets:precompile
}

build_node() {
    npm install
}

write_control() {
    cat > debian/control << EOF
Source: $PACKAGE
Section: unknown
Priority: extra
Maintainer: EF DevOps <devops@edgeflip.com>
Build-Depends: debhelper (>= 7.0.50~)
Standards-Version: 3.9.1
Homepage: $HOMEPAGE

Package: $PACKAGE
Architecture: $DEB_HOST_ARCH
Depends: \${shlibs:Depends}, \${misc:Depends}
Description: $DESCRIPTION
EOF
}

build_package() {
    cd $BUILDS_DIR
    if [ -d $PACKAGE-$VERSION ]
    then
        rm -rf $PACKAGE-$VERSION
    fi
    mkdir $PACKAGE-$VERSION
    mv ${BASE_DIR}/${DEST_DIR} $PACKAGE-$VERSION
    cd $PACKAGE-$VERSION
    yes | dh_make -e devops@edgeflip.com -s --createorig
    echo "${DEST_DIR} ${BASE_DIR}/" > debian/${PACKAGE}.install
    write_control
    rm debian/*.ex debian/*.EX debian/README.*
    dpkg-buildpackage -rfakeroot -us -uc -b
    #dpkg-buildpackage -rfakeroot -b
}

include_in_botbuilds() {
    cd $REPO_DIR
    count=0
    while ! reprepro includedeb botbuilds ${BUILDS_DIR}/${PACKAGE}_${VERSION}-1_${DEB_HOST_ARCH}.deb
    do
        count=$(($count+1))
        if [ "$count" -gt 20 ]
        then
            exit 1
        fi
        sleep 3
    done
}
