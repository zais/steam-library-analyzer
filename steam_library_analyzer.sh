#!/bin/sh
##############################################################################
# Author : https://github.com/zais
# Version: 0.1.20140118.1651
# License: GPLv2 ('gnu.org/licenses/gpl-2.0.html')
##############################################################################
# todo   : rewrite using python (remove most of os level prereqs)
##############################################################################
# Prereqs:
#   Steam level:
#      Profile have to be public (at least when you run update)
#   OS level:
#      perl       ('perl.org')
#      sqlite3    ('sqlite.org')
#      xmlstarlet ('xmlstar.sourceforge.net')
#      wget       ('gnu.org/s/wget')
#      jq         ('stedolan.github.io/jq')
##############################################################################

steam_id="11111111111111111"
friends="11111111111111112 11111111111111113 11111111111111114 11111111111111115" # always a good idea to have filter
log="/tmp/$$.log"

do_process_steam_id() {
  user_id=$1
  # get fresh profile xml
  wget "http://steamcommunity.com/profiles/${user_id}/games?tab=all&xml=1" -O ${user_id}.xml 2>>$log
  
  user_name=$(xmlstarlet sel -t -v gamesList/steamID ${user_id}.xml)
  if [ "x${user_name}" = "x" ]; then
    echo "WARNING: ${user_id} can not be processed (private profile?)."
    return
  fi
  # print what user is being processed
  echo "${user_id} (${user_name})"
  
  
  # [ -f users.csv ] || echo '"id","name"' > users.csv
  echo "\"${user_id}\",\"${user_name}\"" >>users.csv
  
  # [ -f games.csv ] || echo '"id","type","name","genre","category","platform","controller","score","price"' > games.csv
  games_list=$(xmlstarlet sel -t -v gamesList/games/game/appID ${user_id}.xml)
  for id in ${games_list}
  do
    # xml data
    hours_spent=$(xmlstarlet sel -t -v gamesList/games/game[appID=${id}]/hoursOnRecord ${user_id}.xml)
    [ "${hours_spent}x" = "x" ] && hours_spent=0
  
    # assositate user id with game id
    # [ -f users.csv ] || echo '"user_id","game_id"'     > libraries.csv
    echo "\"${user_id}\",\"${id}\",\"${hours_spent}\"" >>libraries.csv
  
    # skip games alredy in csv
    grep '^"'${id}'",' -q games.csv 2>>$log && continue
  
    # get json data
    wget "http://store.steampowered.com/api/appdetails/?appids=${id}&cc=us&l=english" -O ${id}.json 2>>$log
    # jq can not work with numeric node names
    perl -i.orig -pe 's/^\{"'${id}'":/{"game":/' ${id}.json 
    # check if json data valid (api reterned 'success' and we can parse it)
    if [ "$(jq -r '.game.success' ${id}.json)" = "true" ]; then
      # json data
            name=$( jq -r '.game.data.name'                     ${id}.json )
           gtype=$( jq -r '.game.data.type'                     ${id}.json )
           genre=$( jq -r '.game.data.genres[].description'     ${id}.json 2>>$log | perl -pe 's#\n#/#g' | perl -pe 's#/$##g' )
           score=$( jq -r '.game.data.metacritic.score'         ${id}.json 2>>$log | perl -pe 's#null##' )
           price=$( jq -r '.game.data.package_groups[0].subs[0].option_text' ${id}.json 2>>$log | perl -ne 'm/\$(\d+(.\d+)?)/ and print $1' )
        category=$( jq -r '.game.data.categories[].description' ${id}.json 2>>$log | perl -pe 's#\n#;#g' | perl -pe 's#;$##g' )
      controller=$( jq -r '.game.data.controller_support'       ${id}.json 2>>$log | perl -pe 's#null##' )
        platform=$( jq -r '.game.data.platforms.windows'        ${id}.json 2>>$log | grep -q true && printf   win ;
                    jq -r '.game.data.platforms.linux'          ${id}.json 2>>$log | grep -q true && printf ' lin';
                    jq -r '.game.data.platforms.mac'            ${id}.json 2>>$log | grep -q true && printf ' mac' )
  
      # [ "${score}x" = "x" ] && score=0
      # [ "${price}x" = "x" ] && price=0
      # remove temp files
      rm ${id}.json*
  
      # print notice about what game is being added
      echo "    ${name}"
      # add game (one string per category)
      echo "\"${id}\",\"${gtype}\",\"${name}\",\"${genre}\",\"${category}\",\"${platform}\",\"${controller}\",\"${score}\",\"${price}\"" >> games.csv
    else
      echo "WARNING: $id ("$(xmlstarlet sel -t -v gamesList/games/game[appID=${id}]/name ${user_id}.xml)") parse failed."
      mkdir -p failed && mv ${id}.json* failed/
    fi
  done
}


do_update() {
  mv libraries.csv  libraries.csv.$(date +%F)   2>/dev/null
  mv users.csv      users.csv.$(date +%F)       2>/dev/null
  mv games.csv      games.csv.$(date +%F)       2>/dev/null
  mv games.db       games.db.$(date +%F)        2>/dev/null
  mv friends.xml    friends.xml.$(date +%F)     2>/dev/null
  mkdir -p archive && mv *.$(date +%F) archive/ 2>/dev/null
  
  # include friends to db
  echo "$*" | grep -q friends
  if [ $? -eq 0 ]; then
    wget "http://steamcommunity.com/profiles/${steam_id}/friends?xml=1" -O friends.xml 2>>$log
    [ "x${friends}" = "x" ] && friends=$(xmlstarlet sel -t -v friendsList/friends/friend friends.xml)
  else
    friends=""
  fi
  
  # generate csv
  for user_id in ${steam_id} ${friends}
  do
    do_process_steam_id $user_id
    mv ${user_id}.xml archive/
  done
  
  # generate sqlite db for reports :)
  do_generate_csv
}


do_generate_csv() {
sqlite3 games.db <<EOF
create table games (id integer primary key, type text, name text, genre text, category text, platform text, controller text, score integer, price real);
.separator ","
.import games.csv games
delete from games where id='id';
update games set name=replace(name,'™','');
update games set name=replace(name,'®','');
update games set name=replace(name,'–','-');
update games set name=replace(name,'’','''');

create table users (id integer primary key, name text);
.separator ","
.import users.csv users
delete from users where id='id';

create table libraries (user_id integer references users(id), game_id integer references games(id), hours_spent real, primary key (user_id,game_id));
.separator ","
.import libraries.csv libraries
delete from libraries where user_id='user_id';
EOF
}


do_report_summary() {
sqlite3 games.db <<EOF
.head on
.mode line
select name              as "Most Played Game  " from games where id = (select game_id from libraries where user_id=${steam_id} and hours_spent=(select max(hours_spent) from libraries where user_id=${steam_id}));
select round(sum(price)) as "Total USD Spent   " from games where id in (select game_id from libraries where user_id=${steam_id});
select sum(hours_spent)  as "Total Hours Spent " from libraries where user_id=${steam_id};
select count(1)          as "Total Games       " from games where id in (select game_id from libraries where user_id=${steam_id});
EOF
}


do_report_friends_summary() {
sqlite3 games.db <<EOF
.head on
.mode column
.width 20 60
select u.name, gm.name||' ('||lm.hours_spent||' hours)' most_played_game , count(*) total_games, round(sum(l.hours_spent)) total_hours_spent, round(sum(g.price)) total_usd_spent 
from libraries l, users u, games g, games gm, libraries lm
where 1=1
and l.user_id=u.id 
and l.game_id=g.id 
${friends_filter}
and gm.id = lm.game_id
and lm.user_id=u.id
and lm.hours_spent = (select max(hours_spent) from libraries where user_id=u.id)
group by u.name
order by 5 desc;

/*
select u.name,count(*) games, round(sum(hours_spent)) hours_spent, round(sum(price)) usd_spent 
from libraries l, users u, games g 
where l.user_id=u.id and l.game_id=g.id and u.name!=''
group by u.name
order by 4 desc;
*/
EOF
}


do_report_top_games() {
sqlite3 games.db <<EOF
.head on
.mode column
.width 40 20
select name,genre,controller,hours_spent from games g,libraries l where g.id=l.game_id and l.user_id=${steam_id} order by hours_spent desc limit 10;
EOF
}


do_report_top_price() {
sqlite3 games.db <<EOF
.head on
.mode column
.width 40 20
select name,genre,controller,price from games where id in (select game_id from libraries where user_id=${steam_id}) and price between 0 and 1000000 order by price desc limit 10;
EOF
}


do_report_top_score() {
sqlite3 games.db <<EOF
.head on
.mode column
.width 40 20
select name,genre,platform,controller,score from games where id in (select game_id from libraries where user_id=${steam_id}) and score between 0 and 100 order by score desc limit 10;
EOF
}


do_report_local_coop() {
sqlite3 games.db <<EOF
.head on
.mode column
.width 40
select name,platform,controller from games where id in (select game_id from libraries where user_id=${steam_id}) and category like '%Local Co-op%' and type!='dlc';
EOF
}


do_report_remote_coop() {
sqlite3 games.db <<EOF
.head on
.mode column
.width 40
select name,platform,controller 
from games 
where id in (select game_id from libraries where user_id=${steam_id}) and category like '%Co-op%' and category like '%Multi%player%' and type!='dlc';
EOF
}


do_report_friends_coop() {
sqlite3 games.db <<EOF
.head on
.mode column
.width 40 11 8 5 80
select g.name,platform,controller,count(1),group_concat(u.name,', ') comrades
from games g, users u, libraries l
where 1=1
and l.user_id=u.id
and l.game_id=g.id
${friends_filter}
and g.id in (select game_id from libraries where user_id=76561198028086019) and category like '%Co-op%' and category like '%Multi%player%' and type!='dlc'
group by g.name,platform,controller
order by 4 desc
;
EOF
}


do_report_win_only() {
sqlite3 games.db <<EOF
.head on
.mode column
.width 40 50
select name,genre,controller 
from games 
where id in (select game_id from libraries where user_id=${steam_id}) and platform = 'win';
EOF
}


do_report_mac_only() {
sqlite3 games.db <<EOF
.head on
.mode column
.width 40 50
select name,genre,controller 
from games 
where id in (select game_id from libraries where user_id=${steam_id}) and platform = 'win mac';
EOF
}


do_report_lin_only() {
sqlite3 games.db <<EOF
.head on
.mode column
.width 40 50
select name,genre,controller 
from games 
where id in (select game_id from libraries where user_id=${steam_id}) and platform = 'win lin';
EOF
}


do_check() {
  [ ${steam_id} -gt 1 ] 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "ERROR: steam_id is not set (open script and search for steam_id='<your_id_here>')
       Google it (or check 'http://www.gamingstuff.org/steamidhelp.html')"
    exit 1
  fi

  which perl       >/dev/null || \
  which sqlite3    >/dev/null || \
  which xmlstarlet >/dev/null || \
  which wget       >/dev/null || \
  which jq         >/dev/null
  if [ $? -ne 0 ]; then
    echo "ERROR: Check that perl/sqlite3/xmlstarlet/wget/jq are installed."
    exit 1
  fi

  if [ "x${friends}" != "x" ]; then
    friends_filter="and u.id in (${steam_id},$(echo ${friends}|sed -e 's/ /,/g'))"
  fi
}


do_print_help() {
  echo "  Usage:   $0 <options>
  Options: 
           update        - update db/csv your games
           <report_name> - run report (works only if you have db saved locally already)

  Reports:
$(grep '^do_report' $0 | sed -e 's/do_report_//; s/() *{//; s/^/           /g')"
}


##############################################################################
# main logic
##############################################################################
echo ''

[ $# -eq 0 ] && do_print_help && exit
do_check
case $1 in 
    help) do_print_help;;
  update) do_update $* ; do_report_summary;;
       *) do_report_$1;;
esac

echo ''
##############################################################################
