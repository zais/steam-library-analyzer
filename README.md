Steam Library Analyzer (CLI)
======================

Just another steam related trash on the internet.
I'm not a programmer or sql guru, so this is just almost-working tool i'm using to solve my own little problems with Steam client limitations.


Why do I need it?
-----------

Because I'd like to:

***Find local coop enabled games:***
<pre>
$ ./steam_library_analyzer.sh local_coop

name                                      platform    controller
----------------------------------------  ----------  ----------
Shadowgrounds                             win mac               
Shank                                     win lin ma  full      
Shadowgrounds Survivor                    win mac               
Shatter                                   win lin ma  partial   
Trine                                     win mac     partial   
Trine 2: Complete Story                   win lin ma  full      
...
</pre>

***Find windows only games:***
<pre>
$ ./steam_library_analyzer.sh win_only

name                                      genre                                               controller
----------------------------------------  --------------------------------------------------  ----------
Alien Swarm                               Action                                                        
Darkest Hour: Europe '44-'45                                                                            
Vigil: Blood Bitterness                   RPG/Indie                                                     
Titan Quest                               Action/RPG                                                    
Company of Heroes                         Action/Strategy                                               
...
</pre>

***Find coop games which can be played with my frieds:***
<pre>
$ ./steam_library_analyzer.sh friends_coop

name                                      platform    controll  count  comrades
----------------------------------------  ----------  --------  -----  ------------------------------
Left 4 Dead 2                             win lin ma  full      3      John, Bill, Kevin
Magicka                                   win         full      3      Foo, Bill, Kevin 
Terraria                                  win                   3      John, Bill, Kevin
Trine 2: Complete Story                   win lin ma  full      2      Bill, Bar
Alien Swarm                               win                   2      Foo, Bill
...
</pre>



Dependencies:
-----------

***Steam level dependencies:***

* Steam profile have to be public (at least when you run update)
     
***OS level dependencies:***

* [perl](http://perl.org)
* [sqlite3](http://sqlite.org)
* [xmlstarlet](http://xmlstar.sourceforge.net)
* [wget](http://gnu.org/s/wget)
* [jq](http://stedolan.github.io/jq)


How to use:
-----------

1. Copy script to dedicated folder.
2. Edit script and enter your steam id.
3. Run: ``` ./steam_library_analyzer.sh update ``` (add 'friends' if you'd like to analyze friends libraries as well)
4. Play with reports: ``` ./steam_library_analyzer.sh local_coop ```



Steam API used:
-----------
<pre>
* user   : http://steamcommunity.com/profiles/STEAM_ID_HERE/games?tab=all&xml=1
* friends: http://steamcommunity.com/profiles/STEAM_ID_HERE/friends?xml=1
* game   : http://store.steampowered.com/api/appdetails/?appids=GAME_ID_HERE&cc=us&l=english
</pre>
Where STEAM_ID_HERE is 17 digits steam id
and GAME_ID_HERE is game id.
