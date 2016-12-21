# Milestones

## List project milestones

Returns a list of project milestones.

```
GET /projects/:id/milestones
GET /projects/:id/milestones?iid=42
```

```json
[
  {
    "id": 12,
    "iid": 3,
    "project_id": 16,
    "title": "10.0",
    "description": "Version",
    "due_date": "2013-11-29",
    "state": "active",
    "updated_at": "2013-10-02T09:24:18Z",
    "created_at": "2013-10-02T09:24:18Z"
  }
]
```

Parameters:

- `id` (required) - The ID of a project
- `iid` (optional) - Return the milestone having the given `iid`

## Get single milestone

Gets a single project milestone.

```
GET /projects/:id/milestones/:milestone_id
```

Parameters:

- `id` (required) - The ID of a project
- `milestone_id` (required) - The ID of a project milestone

## Create new milestone

Creates a new project milestone.

```
POST /projects/:id/milestones
```

Parameters:

- `id` (required) - The ID of a project
- `title` (required) - The title of an milestone
- `description` (optional) - The description of the milestone
- `due_date` (optional) - The due date of the milestone

## Edit milestone

Updates an existing project milestone.

```
PUT /projects/:id/milestones/:milestone_id
```

Parameters:

- `id` (required) - The ID of a project
- `milestone_id` (required) - The ID of a project milestone
- `title` (optional) - The title of a milestone
- `description` (optional) - The description of a milestone
- `due_date` (optional) - The due date of the milestone
- `state_event` (optional) - The state event of the milestone (close|activate)

## Get all issues assigned to a single milestone

Gets all issues assigned to a single project milestone.

```
GET /projects/:id/milestones/:milestone_id/issues
```

Parameters:

- `id` (required) - The ID of a project
- `milestone_id` (required) - The ID of a project milestone
