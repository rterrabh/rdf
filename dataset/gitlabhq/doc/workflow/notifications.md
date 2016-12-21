# GitLab Notification Emails

GitLab has a notification system in place to notify a user of events that are important for the workflow.

## Notification settings

Under user profile page you can find the notification settings.

![notification settings](notifications/settings.png)

Notification settings are divided into three groups:

* Global Settings
* Group Settings
* Project Settings

Each of these settings have levels of notification:

* Disabled - turns off notifications
* Participating - receive notifications from related resources
* Watch - receive notifications from projects or groups user is a member of
* Global - notifications as set at the global settings

#### Global Settings

Global Settings are at the bottom of the hierarchy.
Any setting set here will be overridden by a setting at the group or a project level.

Group or Project settings can use `global` notification setting which will then use
anything that is set at Global Settings.

#### Group Settings

Group Settings are taking precedence over Global Settings but are on a level below Project Settings.
This means that you can set a different level of notifications per group while still being able
to have a finer level setting per project.
Organization like this is suitable for users that belong to different groups but don't have the
same need for being notified for every group they are member of.

#### Project Settings

Project Settings are at the top level and any setting placed at this level will take precedence of any
other setting.
This is suitable for users that have different needs for notifications per project basis.

## Notification events

Below is the table of events users can be notified of:

| Event                        | Sent to                                                           | Settings level               |
|------------------------------|-------------------------------------------------------------------|------------------------------|
| New SSH key added            | User                                                              | Security email, always sent. |
| New email added              | User                                                              | Security email, always sent. |
| New user created             | User                                                              | Sent on user creation, except for omniauth (LDAP)|
| User added to project        | User                                                              | Sent when user is added to project |
| Project access level changed | User                                                              | Sent when user project access level is changed |
| User added to group          | User                                                              | Sent when user is added to group |
| Group access level changed   | User                                                              | Sent when user group access level is changed | 
| Project moved                | Project members [1]                                               | [1] not disabled |

### Issue / Merge Request events

In all of the below cases, the notification will be sent to:
- Participants:
  - the author and assignee of the issue/merge request
  - authors of comments on the issue/merge request
  - anyone mentioned by `@username` in the issue/merge request description
  - anyone mentioned by `@username` in any of the comments on the issue/merge request

    ...with notification level "Participating" or higher

- Watchers: project members with notification level "Watch"
- Subscribers: anyone who manually subscribed to the issue/merge request

| Event                  | Sent to |
|------------------------|---------|
| New issue              | |
| Close issue            | |
| Reassign issue         | The above, plus the old assignee |
| Reopen issue           | |
| New merge request      | |
| Reassign merge request | The above, plus the old assignee |
| Close merge request    | |
| Reopen merge request   | |
| Merge merge request    | |
| New comment            | The above, plus anyone mentioned by `@username` in the comment, with notification level "Mention" or higher |

You won't receive notifications for Issues, Merge Requests or Milestones
created by yourself. You will only receive automatic notifications when
somebody else comments or adds changes to the ones that you've created or
mentions you.
