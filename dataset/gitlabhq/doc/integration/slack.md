# Slack integration

## On Slack

To enable Slack integration you must create an Incoming WebHooks integration on Slack;

1.  [Sign in to Slack](https://slack.com/signin)

1.  Select **Configure Integrations** from the dropdown next to your team name.

1.  Select the **All Services** tab

1.  Click **Add** next to Incoming Webhooks

1.  Pick Incoming WebHooks

1.  Choose the channel name you want to send notifications to

1.  Click **Add Incoming WebHooks Integration**
    - Optional step; You can change bot's name and avatar by clicking modifying the bot name or avatar under **Integration Settings**.

1. Copy the **Webhook URL**, we'll need this later for GitLab.


## On GitLab

After Slack is ready we need to setup GitLab. Here are the steps to achieve this.

1.  Sign in to GitLab

1.  Pick the repository you want.

1.  Navigate to Settings -> Services -> Slack

1. Pick the triggers you want to activate

1.  Fill in your Slack details
    - Webhook: Paste the Webhook URL from the step above
    - Username: Fill this in if you want to change the username of the bot
    - Channel: Fill this in if you want to change the channel where the messages will be posted
    - Mark it as active
    
1. Save your settings

Have fun :)

*P.S. You can set "branch,pushed,Compare changes" as highlight words on your Slack profile settings, so that you can be aware of new commits when somebody pushes them.*
