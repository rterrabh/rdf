## Log system
GitLab has advanced log system so everything is logging and you can analize your instance using various system log files.
In addition to system log files, GitLab Enterprise Edition comes with Audit Events. Find more about them [in Audit Events documentation](http://doc.gitlab.com/ee/administration/audit_events.html)

System log files are typically plain text in a standard log file format. This guide talks about how to read and use these system log files.

#### production.log
This file lives in `/var/log/gitlab/gitlab-rails/production.log` for omnibus package or in `/home/git/gitlab/log/production.log` for installations from the source.

This file contains information about all performed requests. You can see url and type of request, IP address and what exactly parts of code were involved to service this particular request. Also you can see all SQL request that have been performed and how much time it took.
This task is more useful for GitLab contributors and developers. Use part of this log file when you are going to report bug.

```
Started GET "/gitlabhq/yaml_db/tree/master" for 168.111.56.1 at 2015-02-12 19:34:53 +0200
Processing by Projects::TreeController#show as HTML
  Parameters: {"project_id"=>"gitlabhq/yaml_db", "id"=>"master"}

  ... [CUT OUT]

  amespaces"."created_at" DESC, "namespaces"."id" DESC LIMIT 1[0m  [["id", 26]]
  [1m[35mCACHE (0.0ms)[0m  SELECT  "members".* FROM "members"  WHERE "members"."source_type" = 'Project' AND "members"."type" IN ('ProjectMember') AND "members"."source_id" = $1 AND "members"."source_type" = $2 AND "members"."user_id" = 1  ORDER BY "members"."created_at" DESC, "members"."id" DESC LIMIT 1  [["source_id", 18], ["source_type", "Project"]]
  [1m[36mCACHE (0.0ms)[0m  [1mSELECT  "members".* FROM "members"  WHERE "members"."source_type" = 'Project' AND "members".
  [1m[36m (1.4ms)[0m  [1mSELECT COUNT(*) FROM "merge_requests"  WHERE "merge_requests"."target_project_id" = $1 AND ("merge_requests"."state" IN ('opened','reopened'))[0m  [["target_project_id", 18]]
  Rendered layouts/nav/_project.html.haml (28.0ms)
  Rendered layouts/_collapse_button.html.haml (0.2ms)
  Rendered layouts/_flash.html.haml (0.1ms)
  Rendered layouts/_page.html.haml (32.9ms)
Completed 200 OK in 166ms (Views: 117.4ms | ActiveRecord: 27.2ms)
```
In this example we can see that server processed HTTP request with url `/gitlabhq/yaml_db/tree/master` from IP 168.111.56.1 at 2015-02-12 19:34:53 +0200. Also we can see that request was processed by Projects::TreeController.

#### application.log
This file lives in `/var/log/gitlab/gitlab-rails/application.log` for omnibus package or in `/home/git/gitlab/log/application.log` for installations from the source.

This log file helps you discover events happening in your instance such as user creation, project removing and so on.

```
October 06, 2014 11:56: User "Administrator" (admin@example.com) was created
October 06, 2014 11:56: Documentcloud created a new project "Documentcloud / Underscore"
October 06, 2014 11:56: Gitlab Org created a new project "Gitlab Org / Gitlab Ce"
October 07, 2014 11:25: User "Claudie Hodkiewicz" (nasir_stehr@olson.co.uk)  was removed
October 07, 2014 11:25: Project "project133" was removed
```
#### githost.log
This file lives in `/var/log/gitlab/gitlab-rails/githost.log` for omnibus package or in `/home/git/gitlab/log/githost.log` for installations from the source.

The GitLab has to interact with git repositories but in some rare cases something can go wrong and in this case you will know what exactly happened. This log file contains all failed requests from GitLab to git repository. In majority of cases this file will be useful for developers only.
```
December 03, 2014 13:20 -> ERROR -> Command failed [1]: /usr/bin/git --git-dir=/Users/vsizov/gitlab-development-kit/gitlab/tmp/tests/gitlab-satellites/group184/gitlabhq/.git --work-tree=/Users/vsizov/gitlab-development-kit/gitlab/tmp/tests/gitlab-satellites/group184/gitlabhq merge --no-ff -mMerge branch 'feature_conflict' into 'feature' source/feature_conflict

error: failed to push some refs to '/Users/vsizov/gitlab-development-kit/repositories/gitlabhq/gitlab_git.git'
```

#### satellites.log
This file lives in `/var/log/gitlab/gitlab-rails/satellites.log` for omnibus package or in `/home/git/gitlab/log/satellites.log` for installations from the source.

In some cases GitLab should perform write actions to git repository, for example when it is needed to merge the merge request or edit a file with online editor. If something went wrong you can look into this file to find out what exactly happened.
```
October 07, 2014 11:36: Failed to create satellite for Chesley Weimann III / project1817
October 07, 2014 11:36: PID: 1872: git clone /Users/vsizov/gitlab-development-kit/gitlab/tmp/tests/repositories/conrad6841/gitlabhq.git /Users/vsizov/gitlab-development-kit/gitlab/tmp/tests/gitlab-satellites/conrad6841/gitlabhq
October 07, 2014 11:36: PID: 1872: -> fatal: repository '/Users/vsizov/gitlab-development-kit/gitlab/tmp/tests/repositories/conrad6841/gitlabhq.git' does not exist
```

#### sidekiq.log
This file lives in `/var/log/gitlab/gitlab-rails/sidekiq.log` for omnibus package or in `/home/git/gitlab/log/sidekiq.log` for installations from the source.

GitLab uses background jobs for processing tasks which can take a long time. All information about processing these jobs are writing down to this file.
```
2014-06-10T07:55:20Z 2037 TID-tm504 ERROR: /opt/bitnami/apps/discourse/htdocs/vendor/bundle/ruby/1.9.1/gems/redis-3.0.7/lib/redis/client.rb:228:in `read'
2014-06-10T18:18:26Z 14299 TID-55uqo INFO: Booting Sidekiq 3.0.0 with redis options {:url=>"redis://localhost:6379/0", :namespace=>"sidekiq"}
```

#### gitlab-shell.log
This file lives in `/var/log/gitlab/gitlab-shell/gitlab-shell.log` for omnibus package or in `/home/git/gitlab-shell/gitlab-shell.log` for installations from the source.

gitlab-shell is using by Gitlab for executing git commands and provide ssh access to git repositories.

```
I, [2015-02-13T06:17:00.671315 #9291]  INFO -- : Adding project root/example.git at </var/opt/gitlab/git-data/repositories/root/dcdcdcdcd.git>.
I, [2015-02-13T06:17:00.679433 #9291]  INFO -- : Moving existing hooks directory and simlinking global hooks directory for /var/opt/gitlab/git-data/repositories/root/example.git.
```

#### unicorn_stderr.log
This file lives in `/var/log/gitlab/unicorn/unicorn_stderr.log` for omnibus package or in `/home/git/gitlab/log/unicorn_stderr.log` for installations from the source.

Unicorn is a high-performance forking Web server which is used for serving GitLab application. You can look at this log, for example, if your application does not respond. This log cantains all information about state of unicorn processes at any given time.

```
I, [2015-02-13T06:14:46.680381 #9047]  INFO -- : Refreshing Gem list
I, [2015-02-13T06:14:56.931002 #9047]  INFO -- : listening on addr=127.0.0.1:8080 fd=12
I, [2015-02-13T06:14:56.931381 #9047]  INFO -- : listening on addr=/var/opt/gitlab/gitlab-rails/sockets/gitlab.socket fd=13
I, [2015-02-13T06:14:56.936638 #9047]  INFO -- : master process ready
I, [2015-02-13T06:14:56.946504 #9092]  INFO -- : worker=0 spawned pid=9092
I, [2015-02-13T06:14:56.946943 #9092]  INFO -- : worker=0 ready
I, [2015-02-13T06:14:56.947892 #9094]  INFO -- : worker=1 spawned pid=9094
I, [2015-02-13T06:14:56.948181 #9094]  INFO -- : worker=1 ready
W, [2015-02-13T07:16:01.312916 #9094]  WARN -- : #<Unicorn::HttpServer:0x0000000208f618>: worker (pid: 9094) exceeds memory limit (320626688 bytes > 247066940 bytes)
W, [2015-02-13T07:16:01.313000 #9094]  WARN -- : Unicorn::WorkerKiller send SIGQUIT (pid: 9094) alive: 3621 sec (trial 1)
I, [2015-02-13T07:16:01.530733 #9047]  INFO -- : reaped #<Process::Status: pid 9094 exit 0> worker=1
I, [2015-02-13T07:16:01.534501 #13379]  INFO -- : worker=1 spawned pid=13379
I, [2015-02-13T07:16:01.534848 #13379]  INFO -- : worker=1 ready
```