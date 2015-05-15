from fabric import api as fab

import instances


STAGING = [
    #'edgeflip2-staging-as', 'edgeflip2-staging-celery-as', 'edgeflip2-staging-rmq-as',
    'edgeflip2-staging-64-rmq-vpc-1',
    'edgeflip-staging-web',
    'edgeflip-staging-64-celery-vpc-1',
]
FBSYNC = [
    'eflip-production-fbsync-user-feeds-as', 'eflip-production-fbsync-initial-crawl-as',
    'eflip-production-comments-fbsync-as', 'eflip-production-db-partial-fbsync-as',
    'eflip-production-db-fbsync-as', 'eflip-production-lowpri-fbsync-as',
    'eflip-fbsync-controller-as',
]
FBSYNC_ALL = FBSYNC + ['eflip-production-ebs-fbsync-xl-rmq-as']
TARGETED_CELERY = [
    'eflip-production-celery-as', 'eflip-production-bg-celery-as'
]
TARGETED_WEB = ['eflip-production-as']
TARGETED_SHARING = TARGETED_WEB + TARGETED_CELERY
RMQ = [
    'eflip-production-ebs-fbsync-xl-rmq-as', 'eflip-production-ebs-rmq-as',
]
CONTROLLER = ['eflip-controller-as']
TARGETED_SHARING_COMBO = TARGETED_SHARING + CONTROLLER
PROD_APPS = CONTROLLER + TARGETED_SHARING + FBSYNC
PROD_ALL = PROD_APPS + RMQ


class Hosts(object):
    """Callable returning a list of hostnames within its configured groups,
    providing lazy look-up.

    """
    def __init__(self, group_names):
        self.group_names = group_names
        self._hosts = None

    def iterhosts(self):
        for group in self.group_names:
            for node in instances.from_as_group(group):
                yield node

    def __call__(self):
        if self._hosts is None:
            self._hosts = list(self.iterhosts())
        return self._hosts


fab.env.update(
    user='ubuntu',
    key_filename=['~/.ssh/edgeflip.pem', '~/.ssh/edgeflip_new.pem'],
    roledefs={
        'edgeflip-staging': Hosts(STAGING),
        'edgeflip-fbsync': Hosts(FBSYNC),
        'edgeflip-sharing': Hosts(TARGETED_SHARING),
        'edgeflip-sharing-celery': Hosts(TARGETED_CELERY),
        'edgeflip-sharing-web': Hosts(TARGETED_WEB),
        'edgeflip-sharing-combo': Hosts(TARGETED_SHARING_COMBO),
        'edgeflip-prod-apps': Hosts(PROD_APPS),
        'edgeflip-prod-rmq': Hosts(RMQ),
        'edgeflip-prod-all': Hosts(PROD_ALL),
    },
)


# TASKS #

@fab.task
def restart_puppet():
    fab.sudo('cat /var/run/puppet/agent.pid | xargs kill -HUP')


@fab.task
def remove_configs():
    fab.sudo('rm -rf /root/creds/app')


@fab.task
def health_check():
    fab.sudo('/usr/local/nagios/libexec/check_health')


@fab.task(name='getversion')
def check_version():
    fab.run('grep -E "(v[0-9]+\.[0-9]+.[0-9]+)" /var/www/edgeflip/app_info.json -o')


@fab.task
@fab.parallel
def kick():
    remove_configs()
    restart_puppet()


@fab.task(name='rollingkick')
def rolling_kick():
    remove_configs
    restart_puppet()
    # wait(5) # FIXME


@fab.task
def update_geppetto():
    # sync_repo() # FIXME
    # show_sync_logs() # FIXME
    restart_puppet()
    # wait(30) # FIXME
    # restart_apache() # FIXME


@fab.task
def touch_uwsgi():
    fab.sudo('touch /etc/uwsgi/emperor/*.ini')


@fab.task
def rolling_touch():
    touch_uwsgi()
    # wait(10) # FIXME
