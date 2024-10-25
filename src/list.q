\d .list
ul: {[l; filter; apply] @[l;filter l;apply] };
cl: {[l; n] $[c~last s;-1_;(::)]((0, s),'n,(c:count l)-last s:sums n)sublist\:l };
sl: {[s; sym] `$s vs string sym };
jl: {[s; l] `$s sv string l };
dupl: {[l; n] n#enlist l };
dupe: {[l; n] (n*count l)#l };
diag: { x=/:x:til x };