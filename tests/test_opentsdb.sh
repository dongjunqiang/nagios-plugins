#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2018-01-15 17:59:40 +0000 (Mon, 15 Jan 2018)
#
#  https://github.com/harisekhon/nagios-plugins
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback
#
#  https://www.linkedin.com/in/harisekhon
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x

srcdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$srcdir/.."

. "$srcdir/utils.sh"

section "O p e n T S D B"

export OPENTSDB_VERSIONS="${@:-${OPENTSDB_VERSIONS:-latest 2.2}}"

OPENTSDB_HOST="${DOCKER_HOST:-${OPENTSDB_HOST:-${HOST:-localhost}}}"
OPENTSDB_HOST="${OPENTSDB_HOST##*/}"
OPENTSDB_HOST="${OPENTSDB_HOST%%:*}"
export OPENTSDB_HOST
export OPENTSDB_PORT_DEFAULT=4242
export HAPROXY_PORT_DEFAULT=4242

check_docker_available

trap_debug_env opentsdb

# waits 30 secs just for HBase to come up
startupwait 60

test_opentsdb(){
    local version="$1"
    section2 "Setting up OpenTSDB $version test container"
    docker_compose_pull
    VERSION="$version" docker-compose up -d
    hr
    echo "getting OpenTSDB dynamic port mappings:"
    docker_compose_port "OpenTSDB"
    DOCKER_SERVICE=opentsdb-haproxy docker_compose_port HAProxy
    hr
    when_ports_available "$OPENTSDB_HOST" "$OPENTSDB_PORT" "$HAPROXY_PORT"
    hr
    when_url_content "http://$OPENTSDB_HOST:$OPENTSDB_PORT" "OpenTSDB"
    hr
    echo "checking HAProxy OpenTSDB:"
    when_url_content "http://$OPENTSDB_HOST:$HAPROXY_PORT" "OpenTSDB"
    hr
    if [ -n "${NOTESTS:-}" ]; then
        exit 0
    fi
    hr
    opentsdb_tests
    echo
    section2 "Running OpenTSDB HAProxy tests"
    OPENTSDB_PORT="$HAPROXY_PORT" \
    opentsdb_tests

    echo "Completed $run_count OpenTSDB tests"
    hr
    [ -n "${KEEPDOCKER:-}" ] ||
    docker-compose down
    echo
}

opentsdb_tests(){
    expected_version="$version"
    if [ "$version" = "latest" ]; then
        expected_version=".*"
    fi
    run ./check_opentsdb_version.py -v -e "$expected_version"

    run_fail 2 ./check_opentsdb_version.py -v -e "fail-version"

    run_conn_refused ./check_opentsdb_version.py -v -e "$expected_version"

}

run_test_versions "OpenTSDB"
