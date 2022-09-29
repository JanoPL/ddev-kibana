[![tests](https://github.com/janopl/ddev-kibana/actions/workflows/tests.yml/badge.svg)](https://github.com/janopl/ddev-kibana/actions/workflows/tests.yml) ![project is maintained](https://img.shields.io/maintenance/yes/2022.svg)

## Instalation

Uses [Kibana official image](https://registry.hub.docker.com/_/kibana)

`ddev get janopl/ddev-kibana`

## Configuration

From within the container, the kibana container is reached at hostname "kibana", port: 5601

## Connection

You can access the Kibana server directly from the host by visiting `https://<projectname>.ddev.site:5601`

## Version for Kibana

Version is depends on image using in official addon [drud/ddev-elasticsearch](https://github.com/drud/ddev-elasticsearch)
