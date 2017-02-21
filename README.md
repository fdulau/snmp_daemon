# snmp_daemon
An snmp emulator using multiple network peers to multiplex the various definition (OID, walk, mibs)
The emulator is using a REDIS server as backend DB
The tools alllow you to use : WALK
                              MIBS
                              CONFIGURATION files
It is possible to edit on OID on the fly. (with the tools edit_redis_oid.pl)
e.g.
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -V 3333
                => set a static value for the OID and in the default base (4161)
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -V '$_SE_intA' -d '$_SE_int46=($_SE_intA += int rand(24571116))>24571116 ? $_SE_intA - 24571116 : $_SE_intA' -B 4163
                => a perl code executed and retuenrd in the value (!!! the var name MUST start by $_SE_ and the name could not contain operator like + - ...)
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -D 'counter=24571116'
                => a counter with random increment looping when reaching the value 24571116
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -D 'max=24571116'
                => a random value looping when reaching the value 24571116
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -D 'counter=max32'
                => a counter with random increment looping when reaching the value 2^32
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -D 'max=max32'
                => a random value looping when reaching the value 2^32
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -D 'counter5000=max32'  -B 4162
                => a counter with an increment of 5000 looping when reaching the value 2^32 in the default 4162
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -D 'max1000=max32'  -B 4163
                => a random walue with an increment of 1000 looping when reaching the value 2^32  in the default 4163
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -V 3333
                => set a static value for the OID and in the default base (4161)
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -V '$_SE_intA' -d '$_SE_int46=($_SE_intA += int rand(24571116))>24571116 ? $_SE_intA - 24571116 : $_SE_intA' -B 4163
                => a perl code executed and retuenrd in the value (!!! the var name MUST start by $_SE_ and the name could not contain operator like + - ...)
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -D 'counter=24571116'
                => a counter with random increment looping when reaching the value 24571116
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -D 'max=24571116'
                => a random value looping when reaching the value 24571116
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -D 'counter=max32'
                => a counter with random increment looping when reaching the value 2^32
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -D 'max=max32'
                => a random value looping when reaching the value 2^32
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -D 'counter5000=max32'  -B 4162
                => a counter with an increment of 5000 looping when reaching the value 2^32 in the default 4162
            edit_redis.pl -o  .1.3.6.1.4.1.12356.106.14.2.1.1.21.2 -D 'max1000=max32'  -B 4163
                => a random walue with an increment of 1000 looping when reaching the value 2^32  in the default 4163


The daemon need a configuration file with a separate line for each listener/emulator in the format  peer,def_file,[community]
The community is optional, if missing the community string is 'public'
  e.g.
      127.0.0.1,/opt/conf_snmp_emul/available/eri_2021.walk
      127.0.0.2,/opt/conf_snmp_emul/available/SENSOR-MIB,nonpublic
      127.0.0.3:2162,/opt/conf_snmp_emul/available/cpu.conf

By default the daemon create an UDP command channel on 127.0.0.1:3161
This allow to force a relaod of the config file ( if changed )  or change the DEBUG level
  To reload the configuration file run this:
      echo reload > socat - UDP:127.0.0.1:3161

You start the daemon like this:
      snmp_daemon_multiplex.pl -c configuration_file






