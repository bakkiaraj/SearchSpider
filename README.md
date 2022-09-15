# SearchSpider
Saaral Soft Search Spider is created using perl with GTK+ as a front end.
It is basically a Web Spider, Which can find links from given seed site also search in the found web pages.
In simple terms, It works like a web search engine without indexing any data.
saaral-soft-search-spider is also a good example for Perl GTK2 usage and Using GTK2 widgets inside perl threads. 

To Run this project you need,

1. Perl 5.14 or above with threading enabled (In Windows OS, recommendation is strawberry perl https://strawberryperl.com/ )

2. Glib, Gtk2, Pango, Cairo modules (In windows, These Can be installed via PPM  by adding http://www.sisyphusion.tk/ppm/ repository)

Note: Install the modules in following order

        a. Glib ( Ubuntu: sudo apt install libglib-perl )
        
        b. Pango ( Ubuntu: sudo apt install libpango-perl )
        
        c. Cairo ( Ubuntu: sudo apt install libcairo-perl )
                
        d. Gtk2 ( Ubuntu: sudo apt install libgtk2.0-dev , Install Gtk2 via CPAN)
        
        e. Other modules  
        	( Ubuntu: sudo apt install libmoose-perl libcrypt-ssleay-perl libwww-mechanize-perl libdbi-perl libclass-dbi-sqlite-perl libtext-reform-perl)
        

4. Gtk+ runtime environment 2.24 or above (For windows: http://ftp.gnome.org/pub/GNOME/binaries/win32/gtk+, for Linux: No worry you might have it as part of Gnome)

5. If you plan to edit spiderGui.glade file, Install Glade 3.x (For windows: http://ftp.gnome.org/pub/GNOME/binaries/win32/glade3/3.8/, For Linux: Install via yum / apt-get )

6. In Windows, make sure <Drive>\GTK2-Runtime\bin is in PATH variable.

You are done.Run the following command to get the Search Spider GUI.

Windows OS: searchSpider.bat
Linux: ./searchSpider

Direct perl: perl searchSpider.pl

Note: Many years back, Before GitHub revolution, I had this project hosted in https://code.google.com/archive/p/saaral-soft-search-spider/ 
