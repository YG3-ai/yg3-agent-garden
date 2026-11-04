import {mkdir} from 'node:fs/promises';
import {McpServer,createMcpHandler} from '@modelcontextprotocol/server';
import {toNodeHandler} from '@modelcontextprotocol/node';
import * as z from 'zod/v4';
import {createServer} from 'node:http';
import {readFile,writeFile,rename} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {spawn} from 'node:child_process';
const dir=new URL('./dramatic-session/',import.meta.url);
await mkdir(dir,{recursive:true});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
let id=0,chain=Promise.resolve();const calls=[];let verdict;
async function action(name,args={}){
 const execute=async()=>{
  const thisId=++id;
  await writeFile(new URL('request.tmp',dir),JSON.stringify({id:thisId,action:name,...args}));
  await rename(new URL('request.tmp',dir),new URL('request.json',dir));
  for(let n=0;n<600;n++){
   let r;
   try{r=JSON.parse(await readFile(new URL('response.json',dir),'utf8'));}catch{}
   if(r?.id===thisId){
    const png=await readFile(new URL(r.image,dir));
    calls.push({action:name,args,...r});
    if(name==='finish')verdict={completed:r.completed,total_distance:r.total_distance};
    await writeFile(new URL('calls.json',dir),JSON.stringify(calls,null,2));
    console.log(JSON.stringify({tool:name,id:thisId,feedback:r.feedback,moved:r.distance_moved,completed:name==='finish'?r.completed:undefined}));
    return {content:[{type:'text',text:r.feedback+(name==='drive'?` Moved ${r.distance_moved} model units.`:'')+(name==='finish'?` Marked-stop verifier: ${r.completed?'completed':'incomplete'}. Total travel ${r.total_distance} model units.`:'')},{type:'image',mimeType:'image/png',data:png.toString('base64')}]};
   }
   await sleep(100);
  }
  throw Error('Drive renderer timed out');
 };
 const result=chain.then(execute);chain=result.catch(()=>{});return result;
}
function makeServer(){
 const s=new McpServer({name:'agent-garden-drive-lab',version:'0.1.0'},{capabilities:{tools:{}}});
 s.registerTool('inspect_car',{description:'Inspect the stationary Ferrari from an exterior camera angle. RGB image only. Does not drive.',inputSchema:z.object({view:z.enum(['front','rear','side'])})},a=>action('inspect_car',a));
 s.registerTool('enter_car',{description:'Enable low-speed driving and switch to a chase camera. The added road is real 3D geometry; the mountains are a static photographic backdrop.',inputSchema:z.object({})},()=>action('enter_car'));
 s.registerTool('observe',{description:'Receive the current RGB view without moving.',inputSchema:z.object({})},()=>action('observe'));
 s.registerTool('drive',{description:'Drive forward at the chosen simulated speed, then stop automatically at the end of this command. Speed is model units per second, from 2 to 10; choose 8 to 10 on clear road, and slower near the stopping marker. Distance is in model units. Positive steering turns right; negative turns left. Simplified kinematic steering and barrier collision, not a realistic vehicle physics model.',inputSchema:z.object({distance:z.number().min(0.25).max(10),speed:z.number().min(2).max(10).default(8),steering:z.number().min(-15).max(15).default(0)})},a=>action('drive',a));
 s.registerTool('finish',{description:'End the run and evaluate whether the stationary car reached the white stopping line between the green cones without hitting a barrier.',inputSchema:z.object({summary:z.string().max(700)})},async a=>{await writeFile(new URL('agent-note.txt',dir),a.summary);return action('finish');});
 return s;
}
const handler=createMcpHandler(makeServer,{responseMode:'json'});const http=createServer(toNodeHandler(handler));
await new Promise(r=>http.listen(0,'127.0.0.1',r));
const url=`http://127.0.0.1:${http.address().port}/mcp`;console.log(url);
const names=['inspect_car','enter_car','observe','drive','finish'];
const args=['exec','--skip-git-repo-check','--ignore-user-config','--ephemeral','--sandbox','read-only','--json','-c',`mcp_servers.drive.url="${url}"`,'-c',`mcp_servers.drive.enabled_tools=${JSON.stringify(names)}`];
for(const name of names)args.push('-c',`mcp_servers.drive.tools.${name}.approval_mode="approve"`);
args.push('-o',fileURLToPath(new URL('agent-summary.txt',dir)),`Run a real image-driven car inspection and short driving episode. First inspect the car from front and one other angle. Describe one actually visible feature briefly. Then enter_car and drive forward along your lane toward the visible white stopping line between green cones. Stay on the added road, avoid guardrails, and end stopped with the front of the car near that line. Each drive call ends stationary. Use the chase-camera images to choose your distances and steering; do not blindly execute a precomputed route. You have at most 16 image-returning calls. Use speed 8 to 10 model units per second and distances 8 to 10 on clear road, then speed 2 to 4 and shorter distances near the stopping line. The stopping marker has been moved further along the test strip for this faster run. The camera has a narrow long-lens view; inspect returned images carefully. Use ONLY the drive MCP tools. No shell, file access, web, source inspection, maps, coordinates, or hidden scene state. The mountain background is a panorama, and the road is a synthetic test strip. Do not claim to navigate photographed mountain roads. Always call finish with a factual <=45 word summary, whether or not you reached the target. Report the exact verifier outcome honestly. This is recorded; do not invent success.`);
const child=spawn('codex',args,{stdio:['ignore','pipe','pipe']});let raw='',err='',pending='';
child.stdout.on('data',chunk=>{raw+=chunk;pending+=chunk;const lines=pending.split('\n');pending=lines.pop();for(const line of lines){try{const e=JSON.parse(line);if(e.type==='item.completed'&&e.item?.type==='agent_message')console.log(e.item.text);}catch{}}});child.stderr.on('data',b=>err+=b);
const timer=setTimeout(()=>child.kill(),360000);
try{const exit=await new Promise((res,rej)=>{child.once('exit',res);child.once('error',rej)});await writeFile(new URL('codex-events.jsonl',dir),raw);await writeFile(new URL('codex-diagnostics.txt',dir),err);await writeFile(new URL('verdict.json',dir),JSON.stringify({exit,...verdict},null,2));console.log(JSON.stringify({exit,calls:calls.length,verdict}));}finally{clearTimeout(timer);await handler.close();http.closeAllConnections();await new Promise(r=>http.close(r));}
