# PinaBot

### Overview

**PinaBot** is a very simple [Redd](https://github.com/avinashbot/redd)-based Reddit bot written in Ruby that monitors a subreddit for trigger words and, in turn, posts relevant replies. **PinaBot** also handles unsubscribe requests and stores these requests in a SQLite database.

### Requirements

* Ruby version 2.6 or greater (probably fine with a lesser version but no testing done to verify that)
* [Bundler](https://bundler.io/) is needed to install gems that the bot needs
* [SQLite 3](https://www.sqlite.org/index.html) is required to save reply history and unsubscriptions

## Getting Started

### Registering your bot with Reddit

You'll likely want to create a separate Reddit account for your bot, so that it can have a unique name (i.e. **PinaBot**). After you've done that and have logged in as that bot's account, proceed below:

1. Visit [Preferences / Apps](https://www.reddit.com/prefs/apps/) within Reddit
2. Click "create another app..." button and register your app/bot
3. Set `REDD_CLIENT` in the `.env` file or hardcode into `pinabot.rb`. This value is located directly below the bot's name within the newly created bot in Reddit. It'll look similar to `94eF93wWwmZvyg`.
4. Set `REDD_SECRET` in the `.env` file or hardcode into `pinabot.rb`. This value is labeled as `Secret` within the newly created bot in Reddit.
5. Set `REDD_USERNAME` and `REDD_PASSWORD` for the Reddit account associated with the bot in `.env` or hardcode into `pinabot.rb`.

### Install necessary Gems and prepare database

First, we'll need to install the Gems used by PinaBot:

```shell
$ bundle install
```

Next, let's create the database and run our migrations:

```shell
$ bundle exec rake db:migrate
```

### Configure bot name, author, subreddit...

Per the [Reddit app guidelines](https://github.com/reddit-archive/reddit/wiki/api), every app/bot must have a unique `User-Agent` that must be precisely structured according to their standards. **PinaBot** builds this `User-Agent` string from some configuration data within `pinabot.rb`. It's **very important** that these variables are configured properly prior to running `pinabot.rb`.

The following variables within `pinabot.rb` must be configured prior to first start:

```ruby
VERSION  = '0.0.1'                # increment this after making major changes
AUTHOR   = 'your-reddit-username' # author/handler of bot (e.g. 'GFZDW')
BOTNAME  = 'your-bot-name'        # stylize as needed (e.g. 'PiñaBot')
OPTOUT   = '!unsubscribe'         # trigger phrase to unsubscribe
SUB      = 'your-subreddit'       # PinaBot can only monitor a single subreddit for the time being
```

### Configure Triggers and Replies

**PinaBot** listens for trigger words/phrases and replies accordingly. Triggers and replies are set up using the `DICTIONARY` array within the script:

```ruby
DICTIONARY = [
  {
    # Set 1
    triggers: [
      'pina',
      'pineapple'
    ],
    replies: [
      '[Mmm... pineapple!](https://i.imgur.com/gw7lBej.jpg)',
      'Did somebody mention *la piña?*'
    ]
  },
  {
    # Set 2
    triggers: [
      '#takeitback',
      'take it back'
    ],
    replies: [
      '[Verlander wants to \#TakeItBack!](https://i.imgur.com/ycNuaUv.jpg)',
      '[Altuve wants to \#TakeItBack!](https://i.imgur.com/A9te6cQ.jpg)'
    ]
  }
]
```  

This `DICTIONARY` array can handle as many trigger/reply sets as you like, making **PinaBot** more versatile than some simpler alternatives out there.

## Running PinaBot

**PinaBot** can be run using the following command:

```shell
$ bundle exec ruby pinabot.rb
```

This will run in user mode and can be exited by typing `CTRL-C`.

### Use cron to keep PinaBot running indefinitely

After you've tested your modifications to **PinaBot**, you will likely want it to run in the background. You can use purpose-built programs like **monit** to do this or, more simply, have **cron** handle the job:

#### Open crontab for editing

```shell
$ crontab -e
```

#### Add PinaBot to the crontab:

```ruby
* * * * * ps aux | grep -v grep | grep -q pinabot.rb || bundle exec ruby /path/to/pinabot.rb &
```

This will check every minute to see if `pinabot.rb` is running and will start it if it isn't running. This also starts **PinaBot** after a reboot.

## Questions? Concerns? Want to help?

Use the **Issues** tab to post issues with **PinaBot** and feel free to submit pull requests for recommended changes or bug fixes.

Thanks!