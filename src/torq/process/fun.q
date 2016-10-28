
// use -usage flag to print usage info
\d .proc

// set the torq environment variables if not already set
qhome:{q:getenv[`QHOME]; if[q~""; q:$[.z.o like "w*"; "c:/q"; getenv[`HOME],"/q"]]; q}
/
settorqenv:{[envvar; default]
 if[""~getenv[envvar];
  .lg.o[`init;(string envvar)," is not defined. Defining it to ",val:qhome[],"/",default];
  setenv[envvar; val]];}
\

version:"1.0"
application:""
getversion:{$[0 = count v:@[{first read0 x};hsym`$getenv[`KDBCONFIG],"/version.txt";version];version;v]}
getapplication:{$[0 = count a:@[{read0 x};hsym`$getenv[`KDBCONFIG],"/application.txt";application];application;a]}

\d .lg

// Set the logging table at the top level
// This is to allow it to be published
@[`.;`logmsg;:;([]time:`timestamp$(); sym:`symbol$(); proctype:`symbol$(); host:`symbol$(); loglevel:`symbol$(); id:`symbol$(); message:())];

// Logging functions live in here

// Format a log message
format:{[loglevel;proctype;proc;id;message] "|" sv (string .proc.cp[];string .z.h;string proctype;string proc;string loglevel;string id;message)}

publish:{[loglevel;proctype;proc;id;message]
 if[0<0^pubmap[loglevel];
  // check the publish function exists
  if[@[value;`.ps.initialised;0b];
   .ps.publish[`logmsg;enlist`time`sym`proctype`host`loglevel`id`message!(.proc.cp[];proc;proctype;.z.h;loglevel;id;message)]]]}

// Dictionary of log levels mapped to standard out/err
// Set to 0 if you don't want the log type to print
outmap:@[value;`outmap;`ERROR`ERR`INF`WARN!2 2 1 1]
// whether each message type should be published
pubmap:@[value;`pubmap;`ERROR`ERR`INF`WARN!1 1 0 1]

// Log a message
l:{[loglevel;proctype;proc;id;message;dict]
	$[0 < redir:0^outmap[loglevel];
		neg[redir] .lg.format[loglevel;proctype;proc;id;message];
		ext[loglevel;proctype;proc;id;message;dict]];
        publish[loglevel;proctype;proc;id;message];
	}

// Log an error.
// If the process is fully initialised, throw the error
// If trap mode is set to false, exit
err:{[loglevel;proctype;proc;id;message;dict]
        l[loglevel;proctype;proc;id;message;dict];
        if[.proc.stop;'message];
 	if[.proc.initialised;:()];
        if[not .proc.trap; exit 3];
	}

// log out and log err
// The process name is temporary which we will reset later - once we know what type of process this is
o:l[`INF;`torq;`$"_" sv string (.z.f;.z.i;system"p");;;()!()]
e:err[`ERR;`torq;`$"_" sv string (.z.f;.z.i;system"p");;;()!()]
w:l[`WARN;`torq;`$"_" sv string (.z.f;.z.i;system"p");;;()!()]

// Hook to handle extended logging functionality
// Leave blank
ext:{[loglevel;proctype;proc;id;message;dict]}

banner:{
 width:80;
 format:{"#",(floor[m]#" "),y,((ceiling m:0|.5*x-count y)#" "),"#"}[width - 2];
 blank:"#",((width-2)#" "),"#";
 full:width#"#";
 // print the banner
 -1 full;
 -1 blank;
 -1 format"TorQ v",.proc.getversion[];
 -1 format"AquaQ Analytics";
 -1 format"kdb+ consultancy, training and support";
 -1 blank;
 -1 format"For questions, comments, requests or bug reports please contact us";
 -1 format"w :     www.aquaq.co.uk";
 -1 format"e : support@aquaq.co.uk";
 -1 blank;
 -1 format"Running on ","kdb+ ",(string .z.K)," ",string .z.k;
 if[count customtext:.proc.getapplication[];-1 format each customtext;-1 blank]; // prints custom text from file
 -1 full;}

// Error functions to check the process is in the correct state when being started
\d .err

// Throw an error and exit
ex:{[id;message;code] .lg.e[id;message]; exit code}

// Throw an error based on usage
usage:{ex[`usage;.proc.getusage[];1]}

// Throw an error if all the required parameters aren't passed in
param:{[paramdict;reqparams]
	if[count missing:(reqparams,:()) except key paramdict;
		.lg.e[`init;"missing required command line parameter(s) "," " sv string missing];
		usage[]]}

// Throw an error if all the requried envinonment variables aren't set
env:{[reqenv]
	if[count missing:reqenv where 0=count each getenv each reqenv,:();
		.lg.e[`init;"required environment variable(s) not set - "," " sv string missing];
		usage[]]}

// Check if a variable is null
exitifnull:{[variable]
	if[null value variable;
		.lg.e[`init;"Variable ",(string variable)," is null but must be set"];
		usage[]]}

// Function for replacing environment variables with the associated full path

\d .rmvr

removeenvvar:{
 	// positions of {}
	pos:ss[x]each"{}";
	// check the formatting is ok
	$[0=count first pos; :x;
	1<count distinct count each pos; '"environment variable contains unmatched brackets: ",x;
	(any pos[0]>pos[1]) or any pos[0]<prev pos[1]; '"failed to match environment variable brackets on supplied string: ",x;
	()];

	// cut out each environment variable, and retrieve the meaning
	raze {$["{"=first x;getenv`$1 _ -1 _ x;x]}each (raze flip 0 1+pos) cut x}
/
// Need to get some process information for logging / advertisement purposes
// We can either read these from a file, or from the command line
// default should be from a file, but overridden from the cmd line
// The could also be set in a wrapper script
reqset:0b
if[any req in key `.proc;
	$[all req in key `.proc;
		$[any null `.proc req;
			.lg.o[`init;"some of the required process parameters supplied in the  wrapper script are set to null.  All must be set. Resetting all to null"];
			reqset:1b];
	  .lg.o[`init;"some but not all required process parameters have been set from the wrapper script - resetting all to null"]]];

if[not reqset; @[`.proc;req;:;`]];

$[count[req] = count req inter key params;
	[@[`.proc;req;:;first each `$params req];
	 reqset:1b];
  0<count req inter key params;
	.lg.o[`init;"ignoring partial subset of required process parameters found on the command line - reading from file"];
  ()];
\

\d .proc

getprocs: {discovery "procs"}

getconfig:{[path;level]
        /-check if KDBAPPCONFIG exists
        keyappconf:$[not ""~kac:getenv[`KDBAPPCONFIG];
          key hsym appconf:`$kac,"/",path;
          ()];

        /-if level=2 then all files are returned regardless
        if[level<2;
          if[()~keyappconf;
            appconf:()]];

        /-get KDBCONFIG path
        conf:`$(kc: .proc.torqconfig) ,"/",path;

        /-if level is non-zero return appconfig and config files
        (),$[level;
          appconf,conf;
          first appconf,conf]}

getconfigfile:getconfig[;0]


readprocs:{[file]
	@[
		@/[;
			(`port;`host`proctype`procname);
			("I"$string value each .rmvr.removeenvvar each;"S"$.rmvr.removeenvvar each)
		  ]("****";enlist",")0:;
	       file;
	       {.lg.e[`procfile;"failed to read process file ",(0N!string x)," : ",y]}[file]
	  ]
	}

// Read in the processfile
// Pull out the applicable rows
readprocfile:{[file]
	//order of preference for hostnames
	prefs:(.z.h;`$"." sv string "i"$0x0 vs .z.a;`localhost);
	res:@[{t:select from readprocs[file] where not null host;
	// allow host=localhost for ease of startup
	$[not any null `.proc req;
		select from t where proctype=.proc.proctype,procname=.proc.procname;
		select from t where abs[port]=abs system"p",(lower[host]=lower .z.h) or (host=`localhost) or host=`$"." sv string "i"$0x0 vs .z.a]
		};file;{.err.ex[`init;"failed to read process file ",(string x)," : ",y;2]}[file]];
		if[0=count res;
		.lg.o[`readprocfile;"failed to read any rows from ",(string file)," which relate to this process; Host=",(string .z.h),", IP=",("." sv string "i"$0x0 vs .z.a),", port=",string system"p"];
		:`host`port`proctype`procname!(`;0;proctype;procname)];
		// if more than one result, take the most preferred one
	output:$[1<count res;
		// map hostnames in res to order of preference, select most preferred
		first res iasc prefs?res[`host];
		first res];
	if[not output[`port] = system"p";
		@[system;"p ",string[output[`port]];.err.ex[`readprocfile;"failed to set port to ",string[output[`port]]]];
		.lg.o[`readprocfile;"port set to ",string[output[`port]]]
		];
	output
	}

// redirect std out or std err to a file
// if alias is not null, a softlink will be created back to the actual file
// handle can either be 1 or 2
fileredirect:{[logdir;filename;alias;handle]
	if[not (h:string handle) in (enlist "1";enlist "2");
		'"handle must be 1 or 2"];
	.lg.o[`logging;"re-directing ",h," to",f:" ",logdir,"/",filename];
	@[system;s;{.lg.e[`logging;"failed to redirect ",x," : ",y]}[s:h,f]];
	if[not null `$alias; createalias[logdir;filename;alias]]}

createalias:{[logdir;filename;alias]
	$[.z.o like "w*";
  		.lg.o[`logging;"cannot create alias on windows OS"];
 		[.lg.o[`logging;"creating alias using command ",s:"ln -sf ",filename," ",logdir,"/",alias];
		 @[system;s;{.lg.e[`init;"failed to create alias ",x," : ",y]}[s]]]]}

// Create log files
// logname = base of log file
// timestamp = optional timestamp value (e.g. .z.d, .z.p)
// makealias = if true, will create alias files without the timestamp value
createlog:{[logdir;logname;timestamp;suppressalias]
	basename:(string logname),"_",(string timestamp),".log";
	alias:$[suppressalias;"";(string logname),".log"];
	fileredirect[logdir;"err_",basename;"err_",alias;2];
	fileredirect[logdir;"out_",basename;"out_",alias;1];
	.lg.banner[]}

// function to produce the timestamp value for the log file
logtimestamp:@[value;`logtimestamp;{[x] {[]`$ssr[;;"_"]/[string .z.z;".:T"]}}]

rolllogauto:{[]
	.lg.o[`logging;"creating standard out and standard err logs"];
	createlog[getenv`KDBLOG;procname;logtimestamp[];`suppressalias in key params]}

// utilities to load individual files / paths, and also a complete directory
// this should then be enough to bootstrap
loadf:{
	.lg.o[`fileload;"loading ",x];
	@[{system"l ",x; .lg.o[`fileload;"successfully loaded ",x]};x;{.lg.e[`fileload;"failed to load ",x," : ",y]}[x]]}

loaddir:{
	.lg.o[`fileload;"loading q and k files from directory ",x];
	// Check the directory exists
	if[()~files:key hsym `$x; .lg.e[`fileload;"specified directory ",x," doesn't exist"]; :()];
	// Try to read in a load order file
	$[`order.txt in files:key hsym `$x;
		[.lg.o[`fileload;"found load order file order.txt"];
		 order:(`$read0 `$x,"/order.txt") inter files;
		 .lg.o[`fileload;"loading files in order "," " sv string order]];
		order:`symbol$()];
	files:files where any files like/: ("*.q";"*.k");
	// rearrange the ordering
	files:order,files except order;
	loadf each (x,"/"),/:string files}

// load a config file
loadconfig:{
	file:x,(string y),".q";
	$[()~key hsym`$file;
		.lg.o[`fileload;"config file ",file," not found"];
		[.lg.o[`fileload;"config file ",file," found"];
		 loadf file]]}

// Get the attributes of this process.  This should be overridden for each process
getattributes:{()!()}

// override config variables with parameters from the commandline
overrideconfig:{[params]
	// work out which are the potential variables to override
	ov:key[params] where key[params] like ".*";
	// can only can do those which are already set
	ov:ov where @[{value x;1b};;0b] each ov;
	if[count ov;
		.lg.o[`init;"attempting to override variables ",("," sv string ov)," from the command line"];
		{if[not (abs t:type value y) within (1;-1+count .Q.t);
			.lg.e[`init;"Cannot override ",(string y)," as it is not a basic type"];
			:()];
		 // parse out the values
		 vals:(upper .Q.t abs t)$'x[y];
		 if[t<0;vals:first vals];
		 // check for nulls
		 if[any null each vals; .lg.e[`init;"Cannot override ",(string y)," with command line parameters as null values have been supplied"]];
		 .lg.o[`init;"Setting ",(string y)," to ",-3!vals];
		 set[y;vals]}[params] each ov]}

\d .
