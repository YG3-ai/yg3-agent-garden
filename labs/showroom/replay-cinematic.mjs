import {readFile,writeFile,rename} from 'node:fs/promises';
const source=new URL('./session/',import.meta.url),dest=new URL('./cinematic-session/',import.meta.url);
const calls=JSON.parse(await readFile(new URL('calls.json',source),'utf8'));const output=[];
const pause=ms=>new Promise(r=>setTimeout(r,ms));
for(const call of calls){
 const request={id:call.id,action:call.action,...call.args};
 await writeFile(new URL('request.tmp',dest),JSON.stringify(request));
 await rename(new URL('request.tmp',dest),new URL('request.json',dest));
 let reply;
 for(let i=0;i<1200;i++){
  try{const data=JSON.parse(await readFile(new URL('response.json',dest),'utf8'));if(data.id===call.id){reply=data;break;}}catch{}
  await pause(100);
 }
 if(!reply)throw Error(`Replay timed out at ${call.id}`);
 if(Math.abs(reply.distance_moved-call.distance_moved)>0.005 || reply.collision!==call.collision || reply.completed!==call.completed)throw Error(`Replay outcome differs at ${call.id}`);
 output.push({action:call.action,args:call.args,...reply});
 await writeFile(new URL('calls.json',dest),JSON.stringify(output,null,2));
 console.log(JSON.stringify({id:call.id,action:call.action,moved:reply.distance_moved,matched:true}));
}
const verdict=JSON.parse(await readFile(new URL('verdict.json',source),'utf8'));
await writeFile(new URL('verdict.json',dest),JSON.stringify({...verdict,replay:true,matched_source:true},null,2));
await writeFile(new URL('agent-note.txt',dest),await readFile(new URL('agent-note.txt',source)));
console.log('Cinematic replay completed; all action results matched the original run.');
