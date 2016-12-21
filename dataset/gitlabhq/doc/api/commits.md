# Commits API

## List repository commits

Get a list of repository commits in a project.

```
GET /projects/:id/repository/commits
```

Parameters:

- `id` (required) - The ID of a project
- `ref_name` (optional) - The name of a repository branch or tag or if not given the default branch

```json
[
  {
    "id": "ed899a2f4b50b4370feeea94676502b42383c746",
    "short_id": "ed899a2f4b5",
    "title": "Replace sanitize with escape once",
    "author_name": "Dmitriy Zaporozhets",
    "author_email": "dzaporozhets@sphereconsultinginc.com",
    "created_at": "2012-09-20T11:50:22+03:00",
    "message": "Replace sanitize with escape once"
  },
  {
    "id": "6104942438c14ec7bd21c6cd5bd995272b3faff6",
    "short_id": "6104942438c",
    "title": "Sanitize for network graph",
    "author_name": "randx",
    "author_email": "dmitriy.zaporozhets@gmail.com",
    "created_at": "2012-09-20T09:06:12+03:00",
    "message": "Sanitize for network graph"
  }
]
```

## Get a single commit

Get a specific commit identified by the commit hash or name of a branch or tag.

```
GET /projects/:id/repository/commits/:sha
```

Parameters:

- `id` (required) - The ID of a project
- `sha` (required) - The commit hash or name of a repository branch or tag

```json
{
  "id": "6104942438c14ec7bd21c6cd5bd995272b3faff6",
  "short_id": "6104942438c",
  "title": "Sanitize for network graph",
  "author_name": "randx",
  "author_email": "dmitriy.zaporozhets@gmail.com",
  "created_at": "2012-09-20T09:06:12+03:00",
  "message": "Sanitize for network graph",
  "committed_date": "2012-09-20T09:06:12+03:00",
  "authored_date": "2012-09-20T09:06:12+03:00",
  "parent_ids": [
    "ae1d9fb46aa2b07ee9836d49862ec4e2c46fbbba"
  ]
}
```

## Get the diff of a commit

Get the diff of a commit in a project.

```
GET /projects/:id/repository/commits/:sha/diff
```

Parameters:

- `id` (required) - The ID of a project
- `sha` (required) - The name of a repository branch or tag or if not given the default branch

```json
[
  {
    "diff": "--- a/doc/update/5.4-to-6.0.md\n+++ b/doc/update/5.4-to-6.0.md\n@@ -71,6 +71,8 @@\n sudo -u git -H bundle exec rake migrate_keys RAILS_ENV=production\n sudo -u git -H bundle exec rake migrate_inline_notes RAILS_ENV=production\n \n+sudo -u git -H bundle exec rake assets:precompile RAILS_ENV=production\n+\n ```\n \n ### 6. Update config files",
    "new_path": "doc/update/5.4-to-6.0.md",
    "old_path": "doc/update/5.4-to-6.0.md",
    "a_mode": null,
    "b_mode": "100644",
    "new_file": false,
    "renamed_file": false,
    "deleted_file": false
  }
]
```

## Get the comments of a commit

Get the comments of a commit in a project.

```
GET /projects/:id/repository/commits/:sha/comments
```

Parameters:

- `id` (required) - The ID of a project
- `sha` (required) - The name of a repository branch or tag or if not given the default branch

```json
[
  {
    "note": "this code is really nice",
    "author": {
      "id": 11,
      "username": "admin",
      "email": "admin@local.host",
      "name": "Administrator",
      "state": "active",
      "created_at": "2014-03-06T08:17:35.000Z"
    }
  }
]
```

## Post comment to commit

Adds a comment to a commit. Optionally you can post comments on a specific line of a commit. Therefor both `path`, `line_new` and `line_old` are required.

```
POST /projects/:id/repository/commits/:sha/comments
```

Parameters:

- `id` (required)               - The ID of a project
- `sha` (required)              - The name of a repository branch or tag or if not given the default branch
- `note` (required)             - Text of comment
- `path` (optional)             - The file path
- `line` (optional)             - The line number
- `line_type` (optional)        - The line type (new or old)

```json
{
  "author": {
    "id": 1,
    "username": "admin",
    "email": "admin@local.host",
    "name": "Administrator",
    "blocked": false,
    "created_at": "2012-04-29T08:46:00Z"
  },
  "note": "text1",
  "path": "example.rb",
  "line": 5,
  "line_type": "new"
}
```
