{%- if 'monitor_master' in salt['grains.get']('roles', []) %}

{%- from 'graphite/settings.sls' import graphite with context %}

/tmp/{{ graphite.host }}:
  file.touch

install-deps:
  pkg.installed:
    - names:
      - supervisor
      - memcached
      - python-pip
      - nginx
{%- if grains['os_family'] == 'Debian' %}
      - python-dev
      - sqlite3
      - libcairo2
      - libcairo2-dev
      - python-cairo
      - pkg-config
      - gunicorn
{%- elif grains['os_family'] == 'RedHat' %}
      - python-devel
      - sqlite
      - bitmap
{%- if grains['os'] != 'Amazon' %}
      - bitmap-fonts-compat
{%- endif %}
      - pycairo-devel
      - pkgconfig
      - python-gunicorn
{%- endif %}

{%- if grains['os'] == 'Amazon' %}
{%- set pkg_list = ['fixed-fonts', 'console-fonts', 'fangsongti-fonts', 'lucida-typewriter-fonts', 'miscfixed-fonts', 'fonts-compat'] %}
{%- for fontpkg in pkg_list %}
install-{{ fontpkg }}-on-amazon:
  cmd.run:
    - name: yum -y install http://mirror.centos.org/centos/6/os/x86_64/Packages/bitmap-{{ fontpkg }}-0.3-15.el6.noarch.rpm
{%- endfor %}
{%- endif %}

/tmp/graphite_reqs.txt:
  file.managed:
    - source: salt://graphite/files/graphite_reqs.txt
    - template: jinja
    - context:
      graphite_version: '0.9.12'

install-graphite-apps:
  cmd.wait:
    - name: pip install -r /tmp/graphite_reqs.txt
    - watch:
      - file: /tmp/graphite_reqs.txt

/opt/graphite/webapp/graphite/app_settings.py:
  file.append:
    - text: SECRET_KEY = '34960c411f3c13b362d33f8157f90d958f4ff1494d7568e58e0279df7450445ec496d8aaa098271e'

/opt/graphite/storage/graphite.db:
  file.managed:
    - source: salt://graphite/files/graphite.db
    - replace: False

graphite:
  user.present:
    - group: graphite
    - shell: /bin/false

/opt/graphite/storage:
  file.directory:
    - user: graphite
    - group: graphite
    - recurse:
      - user
      - group

local-dirs:
  file.directory:
    - user: graphite
    - group: graphite
    - names:
      - /var/run/gunicorn-graphite
      - /var/log/gunicorn-graphite
      - /var/run/carbon
      - /var/log/carbon

/opt/graphite/webapp/graphite/local_settings.py:
  file.managed:
    - source: salt://graphite/files/local_settings.py

/opt/graphite/conf/storage-schemas.conf:
  file.managed:
    - source: salt://graphite/files/storage-schemas.conf

/opt/graphite/conf/storage-aggregation.conf:
  file.managed:
    - source: salt://graphite/files/storage-aggregation.conf

/opt/graphite/conf/carbon.conf:
  file.managed:
    - source: salt://graphite/files/carbon.conf
    - template: jinja
    - context:
      graphite_port: {{ graphite.port }}
      graphite_pickle_port: {{ graphite.pickle_port }}

{%- if grains['os_family'] == 'Debian' %}
{%- set supervisor_conf = '/etc/supervisor/supervisord.conf' %}
{%- elif grains['os_family'] == 'RedHat' %}
{%- set supervisor_conf = '/etc/supervisord.conf' %}
{%- endif %}

{{ supervisor_conf }}:
  file.managed:
    - source: salt://graphite/files/supervisord.conf

{%- if grains['os_family'] == 'Debian' %}
supervisor:
{%- elif grains['os_family'] == 'RedHat' %}
supervisord:
{%- endif %}
  service.running:
    - enable: True
    - watch:
      - file: {{ supervisor_conf }}

/etc/nginx/conf.d/graphite.conf:
  file.managed:
    - source: salt://graphite/files/graphite.conf.nginx
    - template: jinja
    - context:
      graphite_host: {{ graphite.host }}

nginx:
  service.running:
    - enable: True
    - reload: True
    - watch:
      - file: /etc/nginx/conf.d/graphite.conf

{%- endif %}
