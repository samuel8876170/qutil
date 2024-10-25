if[not count {$["/"~last x;-1_;::]x}ssr[getenv`QUTIL;"\\";"/"]; -2 "Environment variable not set: QUTIL. Please set it as path to root of q-util"; exit 1];
if[not count key`.import; system"l ",({$["/"~last x;-1_;::]x}ssr[getenv`QUTIL;"\\";"/"]),"/import.q"];
.import.lib`eh.q`time.q`log.q`dz.q;

\d .timer
init: {
    .dz.add[`ts; `.timer.ts];
    rm exec distinct jid from scd where not null jid;
    };
smry: { `valuable`mode`lastRun`nextRun#(select fid, mode, lastRun, nextRun from scd where not null jid) lj select valuable by fid from cb where not null fid };
isrs: {[rootId] rootId in key seqjs };
seqid0: {[rootId] seqjs rootId };
add: {[d]
    if[count missedArgs:`valuable`mode`interval except key d; .log.error "Missing arguments: ",("," sv string missedArgs),"."; :0Ng];
    if[not (d`mode) in validModes:`Once`NextPlus`LastPlus`UntilSucceed`UntilFail`Sequential; .log.error "Invalid job mode: ",(string d`mode),". Supported modes are ",(","sv string validModes),"."; :0Ng];

    d: (`minBreakTime`maxBreakTime`nextRun!(0;0;.time.p[])), d;
    if[`Sequential~d`mode;
        d[`mode`rootJobId]: (`UntilSucceed; rootJobId:rand 0Ng);
        d[`valuable]: (`.timer.exseq; first d`valuable; 1 _ d`valuable; d _ `valuable);
        .z.s d;
        :rootJobId
    ];
    .log.info "Adding new timer job: ",(.Q.s1 d`valuable),", mode: ",(string d`mode),", interval: ",string d`interval;
    guid: 2?0Ng;        //  guid 0: function id  ;  guid 1: timer job id
    $[count fids: exec fid from cb where valuable~\:d`valuable, minTime=d`minBreakTime, maxTime=d`maxBreakTime;
        [
            .log.info "Assigning existing one to timer job because specified function exists.";
            guid[0]: first fids;
        ];
        [
            .log.info "Creating new one and assigning it to timer job because specified function not found.";
            cb,: (guid 0; d`valuable; "v"$0; "v"$d`minBreakTime; "v"$d`maxBreakTime);
        ]
    ];
	scd,: (guid 1; d`mode; guid 0; "p"$0; "n"$d`interval; d`nextRun);
    if[99h~type lastValuable:last d`valuable; if[`rootJobId in key lastValuable; seqjs[lastValuable`rootJobId]: guid 1]];
	guid 1
    };
rm: {[jid]
    if[0 <= type jid; :.z.s each jid];
    if[null jid; :(::)];
    .log.info "Removing timer job: ", string jid;
    targetFid: scd[jid; `fid];
    scd _: jid;
    if[not exec count i from scd where fid = targetFid; cb _: targetFid];
    };
cb: ([fid:`u#"g"$()] valuable:(); penalty:"v"$(); minTime:"v"$(); maxTime:"v"$()) upsert (0Ng;::;0Wv;0Wv;0Wv);
scd: ([jid:`u#"g"$()] mode:`$(); fid:"g"$(); lastRun:"p"$(); interval:"n"$(); nextRun:"p"$()) upsert (0Ng;`;0Ng;0Wp;0Wn;0Wp);
addq: rmq: ();
seqjs: ("g"$())!"g"$();
exseq: {[v; nv; timerJobConfig]
    br: .eh.trp v;
    if[(0b~last br) or not first br; :last br];
    if[not count nv; .timer.seqjs: timerJobConfig[`rootJobId] _ seqjs; :(::)];

    timerJobConfig[`valuable]: (`.timer.exseq; first nv; 1 _ nv; timerJobConfig);
    timerJobConfig[`nextRun]: .time.p[]+timerJobConfig`interval;
    addq,: enlist timerJobConfig;
    last br
    };

ts: {[jids]
    rm rmq;
    add each addq;
    @[`.timer; `addq`rmq; 0#];

	if[all null jids; jids: exec jid from scd where nextRun <= .time.p[]];
	if[not count jids; :(::)];

    t: (select from scd where jid in jids) lj cb;
    brs: flip exec .eh.trp each valuable from t;
    t: update lastRun:.time.p[] from t where jid in jids;
    if[sum isFailed:not first brs; .log.info @' "Failed timer jobs: ",/: (exec .Q.s1 each valuable from t where isFailed) ,' " with error: ",/: (last brs) where isFailed];

    t: update penalty:minTime | maxTime & "v"$((2 xexp; -1+0.5 *)first brs)@'"j"$penalty from t;
    t: update nextRun:nextRun+interval+penalty from t where mode in `NextPlus`UntilFail`UntilSucceed;
    t: update nextRun:lastRun+interval+penalty from t where mode=`LastPlus;

    `.timer.cb upsert select last penalty by fid from t;
    `.timer.scd upsert select last lastRun, last nextRun by jid from t;
    rmq,: raze (
        exec jid from scd where jid in jids, mode=`Once;
        exec jid from scd where jid in jids, mode=`UntilFail`UntilSucceed (first brs) and not 0b ~/: last brs
    );
    };