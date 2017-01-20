\d .clock

then:{etstamp + .z.p - now}

upd:{
 	.clock.etstamp:: .bt.e `etstamp;
	.clock.now:: .z.p;
 }

\d .bt

groupbytstamp: {?[x;();(enlist `etstamp)!enlist `tstamp; allc!allc:cols[x]]} / except `tstamp
transfev:{select event:x, etstamp, data:flip value flip value grpd from grpd:groupbytstamp `dt[x]}
queue: {`etstamp xasc (,/){transfev[x]} each 1_key `dt}

ecounter:0;

doEvent:{[event]
 	e::event;
 	ecounter+::1;
 	f:cols .schema[event`event];
 	x:event`data;
 	data::$[0>type first x;enlist f!x;flip f!x];
 	/.lg.tic[];.port.upd.mtm[]; .lg.toc[`port.upd];
 	/.lg.tic[];.market.upd[]; .lg.toc[`market.upd];
 	.port.upd.mtm[];
 	.market.upd[];
 	.clock.upd[];
	    / port
	    / mtm
	/.strategy.upd[];
	.oms.upd[event`event; .bt.data];
	/ risk
	/ port constr
		/ oms
			/ market (if quotes driven)
			/ port
 }

run:{[]
 	.dt.prepschema[];
 	{doEvent[x]} each select from queue[]; / where etstamp>2016.05.25;
 }

/ ************************************************************************
/todo

/ market process each select by priority from orders.op 
/ rename all size to sz
/ LOW PRIORITY: market order partial fills assuming some measure of overall liquidity