import {mkdir} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import {createRequire} from 'node:module';
import {createServer} from 'node:http';
import {readFile,writeFile,rename} from 'node:fs/promises';
import {spawn} from 'node:child_process';
const req=createRequire(new URL('./package.json',import.meta.url));
const {McpServer,createMcpHandler}=await import(pathToFileURL(req.resolve('@modelcontextprotocol/server')));
const {toNodeHandler}=await import(pathToFileURL(req.resolve('@modelcontextprotocol/node')));
const z=await import(pathToFileURL(req.resolve('zod/v4')));
const dir=new URL('./walk-session/',import.meta.url);
await mkdir(dir,{recursive:true});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
let id=0; const calls=[]; const notes=[]; let chain=Promise.resolve();
async function render(action,args={}){
 const task=async()=>{
  const thisId=++id;
  await writeFile(new URL('request.tmp',dir),JSON.stringify({id:thisId,action,...args}));
  await rename(new URL('request.tmp',dir),new URL('request.json',dir));
  for(let i=0;i<300;i++){
   try{const r=JSON.parse(await readFile(new URL('response.json',dir),'utf8'));
    if(r.id===thisId){const image=await readFile(new URL(r.image,dir));calls.push({id:thisId,action,args,image:r.image,lighting:r.lighting,collision:r.collision,distance_moved:r.distance_moved,clip_start:r.clip_start,clip_end:r.clip_end});await writeFile(new URL('calls.json',dir),JSON.stringify(calls,null,2));return {content:[{type:'text',text:`Observation ${thisId}. Lighting preset: ${r.lighting}. ${action==='move'?`Moved ${r.distance_moved} model units. ${r.collision?'Movement stopped by an obstacle or unsupported floor.':'Path clear.'}`:''} Preview illumination is simulated; not a measurement of real daylight.`},{type:'image',data:image.toString('base64'),mimeType:'image/png'}]};}
   }catch{}
   await sleep(100);
  }
  throw Error('Godot observation timed out');
 };
 const result=chain.then(task); chain=result.catch(()=>{}); return result;
}
function makeServer(){
 const s=new McpServer({name:'agent-garden-home-lab',version:'0.1.0'},{capabilities:{tools:{}}});
 s.registerTool('observe',{description:'Inspect the apartment from your current eye-level position. Returns RGB only.',inputSchema:z.object({})},()=>render('observe'));
 s.registerTool('turn',{description:'Look left (negative degrees) or right (positive degrees), up to 70 degrees per call. Returns a new image. Position stays fixed.',inputSchema:z.object({degrees:z.number().min(-70).max(70)})},a=>render('turn',a));
 s.registerTool('move',{description:'Walk forward, backward, or strafe left/right relative to your current facing. Capsule collision stops movement at furniture/walls; floor check prevents walking into unsupported space. Distance is in uncalibrated model units, not verified meters. Returns image and movement feedback.',inputSchema:z.object({direction:z.enum(['forward','backward','left','right']),distance:z.number().min(0.1).max(1.0)})},a=>render('move',a));
 s.registerTool('set_lighting',{description:'Operate the apartment preview lighting control. Daylight and evening are illustrative lighting presets, not measured sunlight. Returns the changed view.',inputSchema:z.object({mode:z.enum(['daylight','evening'])})},a=>render('set_lighting',a));
 s.registerTool('finish',{description:'Submit a short buyer-facing viewing note based on observed features. Do not infer dimensions or natural light quality. No physical navigation verification.',inputSchema:z.object({summary:z.string().max(800)})},async a=>{notes.push(a.summary);await writeFile(new URL('viewing-note.txt',dir),a.summary);return {content:[{type:'text',text:'Viewing note saved. This was a visual inspection and lighting-control demonstration, not a verified property survey.'}]};});
 return s;
}
const handler=createMcpHandler(makeServer,{responseMode:'json'});
const http=createServer(toNodeHandler(handler));
await new Promise(r=>http.listen(0,'127.0.0.1',r));
const url=`http://127.0.0.1:${http.address().port}/mcp`;
console.log('HOME_MCP',url);
const args=['exec','--skip-git-repo-check','--ignore-user-config','--ephemeral','--sandbox','read-only','--json','-c',`mcp_servers.home.url="${url}"`,'-c','mcp_servers.home.enabled_tools=["observe","turn","move","set_lighting","finish"]'];
for(const n of ['observe','turn','move','set_lighting','finish'])args.push('-c',`mcp_servers.home.tools.${n}.approval_mode="approve"`);
args.push('-o',new URL('agent-summary.txt',dir).pathname.replace(/^\/(\w:)/,'$1'),'You are an embodied AI navigating an apartment in Agent Garden Home Lab. Make a short exploratory walk from the living room toward the kitchen/dining area and, if a clearly open doorway or corridor is accessible, explore toward it. Choose movement from the actual first-person images. Stay in daylight. Use ONLY home MCP tools, no shell/files/web/source or hidden maps. Begin with observe, then move and turn to explore. Move cautiously, typically 0.5 to 0.9 model units per call. You can strafe left/right to pass furniture. If a move is blocked, inspect and change direction rather than retry repeatedly. No need to return to start. Use 10 to 16 image-returning calls total, with at least 5 moves if possible. Give at most one short progress sentence per discovery. Always call finish with a factual summary <=45 words stating where you explored and any obstacles; do not invent entering rooms or reaching goals. The clip will show real movement, not a scripted path.');
const child=spawn('codex',args,{stdio:['ignore','pipe','pipe']});
let raw='',err='';child.stdout.on('data',b=>{raw+=b.toString();for(const line of b.toString().split('\n')){try{const e=JSON.parse(line);if(e.item?.type==='agent_message')console.log(e.item.text);if(e.item?.type==='mcp_tool_call')console.log(e.type,e.item.tool);}catch{}}});child.stderr.on('data',b=>err+=b.toString());
const timer=setTimeout(()=>child.kill(),420000);
try{const exit=await new Promise((res,rej)=>{child.once('exit',res);child.once('error',rej)});await writeFile(new URL('codex-events.jsonl',dir),raw);await writeFile(new URL('codex-diagnostics.txt',dir),err);console.log(JSON.stringify({exit,calls:calls.length,notes}));}finally{clearTimeout(timer);await handler.close();http.closeAllConnections();await new Promise(r=>http.close(r));}
