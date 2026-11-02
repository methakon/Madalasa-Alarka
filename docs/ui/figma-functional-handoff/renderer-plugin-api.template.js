// Madalasa & Alarka Figma functional handoff renderer.
// Used by connected Figma Plugin API, NOT ordinary browser JS.
// __SCREEN_DATA__ replaced with JSON array; __BAND_Y__ replaced with screen start-Y.
// Assumes active Figma file has page 6:2, reusable CTA component 8:7, status 8:9.
// Each tile embeds editable native phone mockup and detailed description BELOW.
const pg=await figma.getNodeByIdAsync("6:2");await figma.setCurrentPageAsync(pg);
await figma.loadFontAsync({family:"Inter",style:"Regular"});await figma.loadFontAsync({family:"Inter",style:"Bold"});
const entries=__SCREEN_DATA__,start=__BAND_Y__,ids=[];
const rgb=h=>({r:parseInt(h.slice(1,3),16)/255,g:parseInt(h.slice(3,5),16)/255,b:parseInt(h.slice(5,7),16)/255}),paint=h=>[{type:"SOLID",color:rgb(h)}];
function box(name,x,y,w,h,fill,round=12,parent=pg){const f=figma.createFrame();f.name=name;f.resize(w,h);f.x=x;f.y=y;f.cornerRadius=round;f.fills=paint(fill);parent.appendChild(f);ids.push(f.id);return f}
function text(str,x,y,w,sz=12,color="#173941",bold=false,parent=pg){const n=figma.createText();n.name=str.slice(0,50);n.fontName={family:"Inter",style:bold?"Bold":"Regular"};n.characters=str;n.fontSize=sz;n.fills=paint(color);n.resize(w,28);n.textAutoResize="HEIGHT";parent.appendChild(n);n.x=x;n.y=y;ids.push(n.id);return n}
const cta=await figma.getNodeByIdAsync("8:7"),status=await figma.getNodeByIdAsync("8:9");
for(let i=0;i<entries.length;i++){
 const d=entries[i],x=480+(i%6)*420,y=start+Math.floor(i/6)*1450;
 const outer=box(d.id+" / "+d.actor+" / "+d.title+" / Developer Spec",x,y,398,1415,"#F1F6F6",20);
 const phone=box("ANDROID / "+d.actor+" / "+d.title,19,15,360,713,"#F9FBFB",25,outer);phone.strokes=paint("#B4CDCC");phone.strokeWeight=1;
 const st=status.createInstance();st.x=18;st.y=12;phone.appendChild(st);ids.push(st.id);
 text(d.title,22,67,316,20,"#164950",true,phone);
 text(d.actor+"  •  "+d.id+"  •  "+d.milestone+"  •  "+d.fr,22,104,318,10,"#6B8585",false,phone);
 const hero=box("Feature focus",17,145,326,124,"#DDF2EC",17,phone);
 text(d.hero,16,15,288,16,"#116E71",true,hero);
 text(d.type.toUpperCase()+" • "+d.milestone+" • FUNCTIONAL CONCEPT",16,86,295,10,"#3B7775",false,hero);
 const parts=d.ui.split(";").map(s=>s.trim()).slice(0,4);
 for(let k=0;k<4;k++){
  const row=box("UI component "+(k+1),17,286+k*80,326,70,k===0?"#ECF7F4":"#FFFFFF",12,phone);
  box("Indicator",0,4,5,62,k===0?"#087E83":"#B8DAD1",2,row);
  text(parts[k]||"Current state and supporting details",17,16,291,12,"#25474B",k===0,row);
 }
 const button=cta.createInstance();phone.appendChild(button);button.x=18;button.y=619;ids.push(button.id);
 const bt=button.findOne(n=>n.type==="TEXT");if(bt&&bt.type==="TEXT"){bt.characters=d.action.slice(0,45);ids.push(bt.id)}
 const notes=box("DEVELOPER IMPLEMENTATION DETAILS • directly below UI",19,748,360,650,"#FFFFFF",17,outer);
 box("Implementation header",0,0,360,60,"#173E48",16,notes);
 text("IMPLEMENTATION HANDOFF",16,9,329,17,"#FFFFFF",true,notes);
 text(d.id+"   "+d.milestone+"   "+d.fr,16,36,328,10,"#B9EEE2",false,notes);
 const fields=[["PURPOSE",d.hero],["UI CONTENT",d.ui],["USER ACTION",d.action],["BACKEND / DATA",d.api],["SECURITY / OS / LEGAL GATE",d.rule],["ERROR / EMPTY / OFFLINE",d.error],["ACCEPTANCE CHECK",d.accept]];
 for(let f=0;f<fields.length;f++){
  const yy=69+f*81;
  text(fields[f][0],14,yy,333,10,"#117D7C",true,notes);
  text(fields[f][1],14,yy+16,332,11,"#2D4248",false,notes);
  if(f<fields.length-1)box("Divider",14,yy+75,332,1,"#E6EFF0",0,notes);
 }
 text(d.title,10,1396,378,11,"#68817F",false,outer);
}
return {createdNodeIds:ids,screenCount:entries.length,first:entries[0].id,last:entries[entries.length-1].id,startY:start,pageId:pg.id};
