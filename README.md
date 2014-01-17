Steam Library Analyzer (CLI)
======================


Dependencies:
-----------

***Steam level dependencies:***


     Profile have to be public (at least when you run update)
     
***OS level dependencies:***

* [perl](http://perl.org)
* [sqlite3](http://sqlite.org)
* [xmlstarlet](http://xmlstar.sourceforge.net)
* [wget](http://gnu.org/s/wget)
* [jq](http://stedolan.github.io/jq)

Steam API used:
-----------
<pre>
* user   : http://steamcommunity.com/profiles/STEAM_ID_HERE/games?tab=all&xml=1
* friends: http://steamcommunity.com/profiles/STEAM_ID_HERE/friends?xml=1
* game   : http://store.steampowered.com/api/appdetails/?appids=GAME_ID_HERE&cc=us&l=english
</pre>
Where STEAM_ID_HERE is 17 digits steam id
and GAME_ID_HERE is game id.
