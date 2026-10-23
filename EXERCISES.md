# Exercises

Work through these in order. Each one builds on the last. Do them from `./lab shell`
(you land in `~/lab`, which is `./workspace` on your host, so you can edit files in
VS Code and run them in the container).

Rule of the lab: if a node gets into a weird state, don't fix it by hand. Run
`./lab reset` and make your playbook handle it.

---

## 1. Ad-hoc commands

Goal: get comfortable with `ansible <pattern> -m <module> -a <args>`.

1. Show the uptime of every node: `ansible all -a uptime`
2. Show free disk on only the RHEL family: target the `rocky` group.
3. Install `htop` on `ubuntu2` only, with `ansible.builtin.package` and `--become`.
4. Run step 3 again. Note `changed` vs `ok`.

**Check:** `ansible ubuntu2 -m ansible.builtin.command -a "which htop"`

## 2. Inventory patterns

1. List hosts in `web` but not `rocky`: `ansible 'web:!rocky' --list-hosts`
2. List hosts in both `web` and `ubuntu`: `ansible 'web:&ubuntu' --list-hosts`
3. Add a new group `staging` containing `ubuntu2` and `rocky1`. Give it a group var `env_name: staging`.
4. `ansible-inventory --graph` and `ansible-inventory --host rocky1`

## 3. Facts and conditionals

1. Run `./lab run 01-facts.yml`.
2. Write `playbooks/10-facts.yml` that prints the total memory and CPU count of each host.
3. Add a task that only runs on hosts with more than 1 vCPU.
4. Cache facts with `fact_caching = jsonfile` in `ansible.cfg` and time a run before and after.

## 4. Idempotence

1. Run `./lab run site.yml` twice. The second run must show `changed=0`.
2. Write a task with `ansible.builtin.shell: echo hi >> /tmp/log`. Run it twice. Why does it always report changed?
3. Fix it two ways: with `creates:`, then with `ansible.builtin.lineinfile`.

## 5. Check mode and diff

1. Edit `webserver_message` in `inventory/group_vars/web.yml`.
2. `./lab run site.yml --check --diff` and read the diff before applying.
3. Apply it and reload <http://localhost:8081>.

## 6. Handlers

1. Change `lab-headers.conf.j2` to add a second header.
2. Run `03-webserver.yml`. Confirm the handler fired once per host.
3. Run it again. Confirm it did not fire.
4. Break the template on purpose (remove the `;`). What does the `Check nginx config` handler do?

**Check:** `curl -sI localhost:8081 | grep -i x-lab`

## 7. Loops and variables

1. Add a third user to `lab_users` with an extra field `shell: /bin/sh`. Make the `user` task use it when present (`item.shell | default('/bin/bash')`).
2. Give users an `state: absent` option and remove `bob`.
3. Find where a variable comes from: set `webserver_message` in role defaults, group_vars and `-e`. Which wins?

## 8. Write your own role

Create `roles/timekeeping` (or `roles/logrotate`, `roles/cron_jobs`, your choice) with
`ansible-galaxy role init roles/<name>`.

1. Must work on Ubuntu and Rocky (use `vars/<os_family>.yml` like `webserver`).
2. Must be idempotent.
3. Add it to `site.yml` behind a tag and run only that tag: `./lab run site.yml -t <tag>`.

## 9. Ansible Vault

1. `ansible-vault create inventory/group_vars/db/vault.yml` with `vault_db_password: ...`
2. Move existing `group_vars/db.yml` (if any) to `group_vars/db/vars.yml` and reference `{{ vault_db_password }}`.
3. Write a task that drops it into `/etc/app.env` with mode `0600` and `no_log: true`.
4. Run with `--ask-vault-pass`. Then set up a `vault_password_file` that is git-ignored.

## 10. Database tier

1. Write `playbooks/04-db.yml` that installs PostgreSQL on the `db` group, starts it and creates a database and user (use `community.postgresql`; add it to `control/requirements.yml`, then `./lab reset`).
2. Add a check that `web` hosts can reach the db port (`ansible.builtin.wait_for` with `delegate_to`).

## 11. Rolling changes

1. In `03-webserver.yml` set `serial: 1` and add `max_fail_percentage: 0`.
2. Make the page change on purpose and watch it roll one host at a time.
3. Add a pre-task that fails on `rocky1` only, and see the rollout stop.

## 12. Break it, rebuild it

1. `./lab console ubuntu1` and `apt-get remove -y nginx`.
2. Run `site.yml`. Ansible should put it back. That is configuration drift being corrected.
3. Now `./lab reset` and run `site.yml` on a brand-new lab. Same result from zero: that is the immutable approach.

---

Stretch: add `molecule` to test your role in isolation, or point the same playbooks
at a cloud VM by adding it to the inventory.
