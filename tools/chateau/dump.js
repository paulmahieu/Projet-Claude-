const vm=require('vm'),fs=require('fs');
const src=fs.readFileSync(process.argv[2],'utf8');
const ctx={Math,console:{log(){}}};ctx.window=ctx;ctx.globalThis=ctx;ctx.self=ctx;
vm.createContext(ctx);vm.runInContext(src,ctx,{timeout:20000});
const G=ctx.CastleGen||ctx.window.CastleGen;
const root=G.buildCastle();
const out=[];
(function walk(n,path){ if(n.kind==='Part'){out.push({n:n.name,path,cls:n.cls,shape:n.shape,s:[n.size.x,n.size.y,n.size.z],cf:[n.cf.x,n.cf.y,n.cf.z,...n.cf.r],c:n.color,m:n.mat,t:n.transparency,cc:n.canCollide,anch:n.anchored});}
 if(n.children) n.children.forEach(ch=>walk(ch,path+'/'+(n.name||'')));})(root,'');
fs.writeFileSync(process.argv[3],JSON.stringify(out));
console.error('parts',out.length,'count',root.partCount);
const keys=Object.keys(root.children? root.children[0]:{}); console.error(keys);
