# What it is
This is a simple bash script to update a dynamic IP with the Linode API. 

It can update as many domains as you like, but only for one Linode account/API Key.

#How to use

All commands are in quotes ("")!


Set your API key, which can be found at https://manager.linode.com/profile with  "echo MY_API_KEY > .key"


###Get your Domain ID and your Resource ID

For Domain ID run the command "./dyndns.sh list_domains" 

For Resource ID run the command "./dyndns.sh list_resources DOMAIN_ID" - where DOMAIN_ID is the number from the command above!

Do this for all the domains/resources you want to update. Tips: write them down as you go along :-)

Then you have to create your domains and resource files.

Like this : "echo xxx,yyy,zzz > .domains" and "echo aaa,bbb,ccc > .resources" where 'xxx,yyy...' and 'aaa,bbb...' are your domain and resource IDs

Make a cron job with the script eg "crontab -e" with the command "0,30       *   *   *   *   /path/to/script/dyndns.sh update"

The entry above will run the script once every 30 minutes.


To get a list of your active domain and resource IDs and active IP run the command "./dyndns.sh dns_info"


Original script by [Andrew Childs](https://github.com/andrewchilds/linode-dyn-dns)

Modified by [Rune Gulbrandsøy] (http://ghostblog.be)

