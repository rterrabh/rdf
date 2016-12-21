# GitLab API

## Resources

- [Users](users.md)
- [Session](session.md)
- [Projects](projects.md) including setting Webhooks
- [Project Snippets](project_snippets.md)
- [Services](services.md)
- [Repositories](repositories.md)
- [Repository Files](repository_files.md)
- [Commits](commits.md)
- [Branches](branches.md)
- [Merge Requests](merge_requests.md)
- [Issues](issues.md)
- [Labels](labels.md)
- [Milestones](milestones.md)
- [Notes](notes.md) (comments)
- [Deploy Keys](deploy_keys.md)
- [System Hooks](system_hooks.md)
- [Groups](groups.md)
- [Namespaces](namespaces.md)
- [Settings](settings.md)

## Clients

Find API Clients for GitLab [on our website](https://about.gitlab.com/applications/#api-clients).
You can use [GitLab as an OAuth2 client](oauth2.md) to make API calls.

## Introduction

All API requests require authentication. You need to pass a `private_token` parameter by URL or header. If passed as header, the header name must be "PRIVATE-TOKEN" (capital and with dash instead of underscore). You can find or reset your private token in your profile.

If no, or an invalid, `private_token` is provided then an error message will be returned with status code 401:

```json
{
  "message": "401 Unauthorized"
}
```

API requests should be prefixed with `api` and the API version. The API version is defined in `lib/api.rb`.

Example of a valid API request:

```
GET http://example.com/api/v3/projects?private_token=QVy1PB7sTxfy4pqfZM1U
```

Example for a valid API request using curl and authentication via header:

```
curl --header "PRIVATE-TOKEN: QVy1PB7sTxfy4pqfZM1U" "http://example.com/api/v3/projects"
```

The API uses JSON to serialize data. You don't need to specify `.json` at the end of API URL.

## Authentication with OAuth2 token

Instead of the private_token you can transmit the OAuth2 access token as a header or as a parameter.

### OAuth2 token (as a parameter)

```
curl https://localhost:3000/api/v3/user?access_token=OAUTH-TOKEN
```

###  OAuth2 token (as a header)

```
curl -H "Authorization: Bearer OAUTH-TOKEN" https://localhost:3000/api/v3/user
```

Read more about [GitLab as an OAuth2 client](oauth2.md).

## Status codes

The API is designed to return different status codes according to context and action. In this way if a request results in an error the caller is able to get insight into what went wrong, e.g. status code `400 Bad Request` is returned if a required attribute is missing from the request. The following list gives an overview of how the API functions generally behave.

API request types:

- `GET` requests access one or more resources and return the result as JSON
- `POST` requests return `201 Created` if the resource is successfully created and return the newly created resource as JSON
- `GET`, `PUT` and `DELETE` return `200 OK` if the resource is accessed, modified or deleted successfully, the (modified) result is returned as JSON
- `DELETE` requests are designed to be idempotent, meaning a request a resource still returns `200 OK` even it was deleted before or is not available. The reasoning behind it is the user is not really interested if the resource existed before or not.

The following list shows the possible return codes for API requests.

Return values:

- `200 OK` - The `GET`, `PUT` or `DELETE` request was successful, the resource(s) itself is returned as JSON
- `201 Created` - The `POST` request was successful and the resource is returned as JSON
- `400 Bad Request` - A required attribute of the API request is missing, e.g. the title of an issue is not given
- `401 Unauthorized` - The user is not authenticated, a valid user token is necessary, see above
- `403 Forbidden` - The request is not allowed, e.g. the user is not allowed to delete a project
- `404 Not Found` - A resource could not be accessed, e.g. an ID for a resource could not be found
- `405 Method Not Allowed` - The request is not supported
- `409 Conflict` - A conflicting resource already exists, e.g. creating a project with a name that already exists
- `422 Unprocessable` - The entity could not be processed
- `500 Server Error` - While handling the request something went wrong on the server side

## Sudo

All API requests support performing an api call as if you were another user, if your private token is for an administration account. You need to pass  `sudo` parameter by URL or header with an id or username of the user you want to perform the operation as. If passed as header, the header name must be "SUDO" (capitals).

If a non administrative `private_token` is provided then an error message will be returned with status code 403:

```json
{
  "message": "403 Forbidden: Must be admin to use sudo"
}
```

If the sudo user id or username cannot be found then an error message will be returned with status code 404:

```json
{
  "message": "404 Not Found: No user id or username for: <id/username>"
}
```

Example of a valid API with sudo request:

```
GET http://example.com/api/v3/projects?private_token=QVy1PB7sTxfy4pqfZM1U&sudo=username
```

```
GET http://example.com/api/v3/projects?private_token=QVy1PB7sTxfy4pqfZM1U&sudo=23
```

Example for a valid API request with sudo using curl and authentication via header:

```
curl --header "PRIVATE-TOKEN: QVy1PB7sTxfy4pqfZM1U" --header "SUDO: username" "http://example.com/api/v3/projects"
```

```
curl --header "PRIVATE-TOKEN: QVy1PB7sTxfy4pqfZM1U" --header "SUDO: 23" "http://example.com/api/v3/projects"
```

## Pagination

When listing resources you can pass the following parameters:

- `page` (default: `1`) - page number
- `per_page` (default: `20`, max: `100`) - number of items to list per page

[Link headers](http://www.w3.org/wiki/LinkHeader) are send back with each response. These have `rel` prev/next/first/last and contain the relevant URL. Please use these instead of generating your own URLs.

## id vs iid

When you work with API you may notice two similar fields in api entities: id and iid. The main difference between them is scope. Example:

Issue:

    id: 46
    iid: 5

- id - is unique across all issues. It's used for any api call.
- iid - is unique only in scope of a single project. When you browse issues or merge requests with Web UI, you see iid.

So if you want to get issue with api you use `http://host/api/v3/.../issues/:id.json`. But when you want to create a link to web page - use  `http:://host/project/issues/:iid.json`

## Data validation and error reporting

When working with the API you may encounter validation errors. In such case, the API will answer with an HTTP `400` status.
Such errors appear in two cases:

* A required attribute of the API request is missing, e.g. the title of an issue is not given
* An attribute did not pass the validation, e.g. user bio is too long

When an attribute is missing, you will get something like:

    HTTP/1.1 400 Bad Request
    Content-Type: application/json

    {
        "message":"400 (Bad request) \"title\" not given"
    }

When a validation error occurs, error messages will be different. They will hold all details of validation errors:

    HTTP/1.1 400 Bad Request
    Content-Type: application/json

    {
        "message": {
            "bio": [
                "is too long (maximum is 255 characters)"
            ]
        }
    }

This makes error messages more machine-readable. The format can be described as follow:

    {
        "message": {
            "<property-name>": [
                "<error-message>",
                "<error-message>",
                ...
            ],
            "<embed-entity>": {
                "<property-name>": [
                    "<error-message>",
                    "<error-message>",
                    ...
                ],
            }
        }
    }
