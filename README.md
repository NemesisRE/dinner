![logo](https://nrecom.net/templates/corporate_response/images/s5_logo.png)
#Android Dinner
*...if you have no time to breakfast, brunch or lunch.*


##What is Dinner?
**Dinner** is a build script for comfortable and automated building of Android Roms. More or less it's a wrapper for breakfast, repo sync and brunch...

But **Dinner** is more than that. It uses configs to define a build, these configs can be shared with others so they can build what you built. And there is even more:

 * Nice output (only the information you need)
 * Commandline completion for **Dinner**
 * Complete logfile of your build and a errorlog which only contains message from STDERR
 * Automatic upload of errorlog to our secure [Stikked server](https://github.com/claudehohl/Stikked) (https://paste.nrecom.net)
 * Generating of a changelog
 * Notification about you build status via Mail, Pushbullet or Notify my Android
 * Build via cron, no need for a jenkins or a build bot, you only need **Dinner**
 * still much more...

##Who is it intended for?
Developers and Users, everyone can use and benefit from it.

Developers can attache their **Dinner** config to the rom thread so that users can build their rom.

Users have an easier way to compile a rom and support the devs by sending the errorlog back to them.

##What are the requirements?
At the moment you need a build environment, which means you have to install all packages need to compile android (examples from: [Google](http://source.android.com/source/initializing.html) or [OmniRom](http://docs.omnirom.org/Setting_Up_A_Compile_Environment))

 * You should also have a build user (do not build as root or with root privileges).
 * And "mutt" if you want to send e-mail notifications.

##How to install?
Dinner installation is quite easy, as build user just run:
```bash
curl -sL https://raw.github.com/NemesisRE/dinner/master/bootstrap.sh | /bin/bash
```

or clone the repository and add the folloing lines to ${HOME}/.bashrc (or for zsh: ${HOME}/.zshrc):
```bash
source [DINNER_INSTALL_PATH]/helper/dinner_completion.sh
export PATH=\$PATH:[DINNER_INSTALL_PATH]/bin
```

##How to use it?
###Dinner help
**Dinner** has a good help, run:
```bash
dinner help
```
and you will get pretty much all information you need.

###How to start
First thing, create a config! Just run:
```bash
dinner config add NAME_OF_YOUR_NEW_CONFIG
```
or just add an existing:
```bash
dinner config add PATH_TO_CONFIG
```
if you want to change some of the advanced config variables use:
```bash
dinner config edit NAME_OF_YOUR_CONFIG
```

After you created your config, all you need to do is start building process by running:
```bash
dinner build NAME_OF_YOUR_CONFIG
```
or if you want to build all your configs:
```bash
dinner build
```


##Is Dinner already finished?
No! I want to add even more features, at the moment easy cherrypicking is one of my main goals. But I think there will be even more ideas from you.
