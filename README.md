[![tests](https://github.com/janopl/ddev-kibana/actions/workflows/tests.yml/badge.svg)](https://github.com/janopl/ddev-kibana/actions/workflows/tests.yml) ![project is maintained](https://img.shields.io/maintenance/yes/2023.svg)

## Instalation

Uses [Kibana official image](https://registry.hub.docker.com/_/kibana)

`ddev get janopl/ddev-kibana`

## Configuration

From within the container, the kibana container is reached at hostname "kibana", port: 5601

## Connection

You can access the Kibana server directly from the host by visiting:

- `https://<projectname>.ddev.site:5601`
- `http://<projectname>.ddev.site:5600`

## Contribution

If you want to contribute to this project, you need to follow these steps:

1. Fork this repository on GitHub.
2. Clone your forked repository to your local machine.
3. Add the original repository as a remote called `upstream`.
4. Create a new branch for your feature or bugfix.
5. Initialize and update the git submodules in your local repository.
6. Make your changes and commit them to your branch.
7. Push your branch to your forked repository on GitHub.
8. Create a pull request from your branch to the `main` branch of the original repository.

### Git submodules

This project uses git submodules to include external libraries or dependencies. 
A git submodule is a record within a host git repository that points to a specific commit in another external repositories
[bats-assert](https://github.com/ztombol/bats-assert) and [bats-support](https://github.com/ztombol/bats-support).
Submodules are very static and only track specific commits.
Submodules do not track git refs or branches and are not automatically updated when the host repository is updated.

To initialize and update the git submodules in your local repository, you need to run the following commands:

```shell
  git submodule update --init --recursive
```
