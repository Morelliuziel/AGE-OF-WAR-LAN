import processing.net.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.io.*;


final int W=1280, H=720;
final float SUELO=494;
final float BASE_IZQUIERDA_X=100.0f, BASE_DERECHA_X=1180.0f;
final float BASE_ANCHO=192.0f, BASE_ALTO=198.0f;
final float FRENTE_BASE_IZQUIERDA=BASE_IZQUIERDA_X+BASE_ANCHO*.5f;
final float FRENTE_BASE_DERECHA=BASE_DERECHA_X-BASE_ANCHO*.5f;
final float ALTURA_DISPARO=SUELO-43.0f;
final float TORRE_IZQUIERDA_X=BASE_IZQUIERDA_X+14.0f;
final float TORRE_DERECHA_X=BASE_DERECHA_X-14.0f;
float alturaTorre(int slot){return SUELO-BASE_ALTO+(slot==1?34.0f:2.0f);}
final int PUERTO_UDP=8888, PUERTO_TCP=12345;
final int LOBBY=0, JUGANDO=1, GAME_OVER=2;
final int SPAWN_UNIT=1, UPDATE_POS=2, BASE_HP=3, SPAWN_PARTICLE=4;
final int FIN_PARTIDA=5, BUY_TURRET=6, SPECIAL_ABILITY=7;
final int EVOLVE_ERA=8, ATTACK_EVENT=9, SELL_TURRET=10;
final int[] VIDA_BASE={500,1000,2000};
final int[] ORO_EVOLUCION={0,500,1200};
final int[] XP_EVOLUCION={0,250,650};
final int[][] COSTOS={{25,75,200},{100,200,400},{800,400,1200}};
final int[][] VIDAS={{50,35,150},{100,60,300},{450,200,900}};
final int[][] DANIOS={{10,8,25},{20,18,45},{70,40,120}};
final float[][] RANGOS={{13,150,17},{15,200,17},{18,250,300}};
final float[][] VELOCIDADES={{64,61,44},{59,58,43},{43,58,31}};
final float[][] CICLOS={{0.87f,1.15f,1.30f},{0.83f,1.18f,1.34f},{1.34f,0.88f,1.65f}};
final int[][] ANCHOS={{28,29,64},{32,31,54},{60,37,75}};
final int[][] ALTOS={{57,59,92},{61,62,87},{95,66,98}};
final int[] DANIO_ESPECIAL={50,120,250};
final int[] COSTO_TORRE={500,1000,1500};
final int[] DANIO_TORRE={8,18,42};
final float[] RANGO_TORRE={250,310,390};
final String[] ERA_NOMBRE={"CAVERNICOLA","MEDIEVAL","FUTURISTA"};
final String[][] NOMBRES={
 {"Cavernicola","Cazador con honda","Jinete de dinosaurio"},
 {"Espadachin","Arquero","Caballero blindado"},
 {"Mech de asalto","Soldado laser","Tanque de plasma"}
};
final int MAX_UNIDADES=8;
final int ORO_INICIAL=250;
final float ORO_SEGUNDO=2.0f;
final int TX_SYNC_MS=100; 
final float CD_ESPECIAL=60.0f;
final float SITIO_IZQUIERDA=220.0f, SITIO_DERECHA=1060.0f;
final float SPAWN_IZQUIERDA=128.0f, SPAWN_DERECHA=1152.0f;
final int[] BONUS_ORO_ERA={12,35,85};


Server s;
Client c;
boolean esServidor=false;
String serverIP="";
int myID=-1; // 0 servidor; 1 cliente
volatile boolean buscando=true, conexionActiva=true;
volatile boolean clienteConectado=false;
volatile String textoRed="Buscando Servidor en LAN...";
volatile Client remoto=null;
DatagramSocket servidorUDP;
final Object candadoEnvio=new Object();
ArrayList<String> lineasRecibidas=new ArrayList<String>();
ArrayList<Unidad> listaEntidades=new ArrayList<Unidad>();
ArrayList<Proyectil> listaProyectiles=new ArrayList<Proyectil>();
ArrayList<Particula> listaParticulas=new ArrayList<Particula>();
HashMap<Integer,Unidad> indiceUnidades=new HashMap<Integer,Unidad>();
Jugador[] jugadores={new Jugador(0),new Jugador(1)};
Torreta[][] torres=new Torreta[2][2];
int pantalla=LOBBY, ganador=-1, idHost=1, idClienteAutorizado=100000;
int ultimoFrame=0, ultimoSync=0;
float acumuladorOro=0;
boolean listoLocal=false, clientePreparado=false, revanchaHost=false, revanchaCliente=false;
String notificacion="";
int notificacionHasta=0;


HashMap<String,PImage[]> animaciones=new HashMap<String,PImage[]>();
PImage[] imagenBase=new PImage[3], imagenTorre=new PImage[3];
PImage fondoOriginal=null;
PImage[][] spritesSimples=new PImage[3][3];
PImage spriteBala;
PImage fondoCache=null;
float[][] escalaVisual=new float[3][3];
StringBuilder envioPendiente=new StringBuilder(10240);


void setup(){
  size(1280,720);
  frameRate(60);
  surface.setTitle("Age Of War LAN - 1V1");
  textFont(createFont("SansSerif",15));
  generarDibujos();
  generarFondo();
  cargarOriginales();
  ultimoFrame=millis();
  thread("descubrirYConectar");
}

void draw(){
  int ahora=millis();
  float dt=constrain((ahora-ultimoFrame)/1000.0f,0,0.055f);
  ultimoFrame=ahora;
  consumirCola();
  if(pantalla==JUGANDO){
    if(esServidor) simularServidor(dt);
    else actualizarReplica(dt);
  }
  actualizarParticulas(dt);
  if(pantalla==LOBBY) dibujarLobby();
  else {
    dibujarCampo();
    dibujarParticulas();
    dibujarHUD();
    dibujarSaludBases();
    if(pantalla==GAME_OVER) dibujarFinal();
  }
  if(!notificacion.equals("")&&ahora<notificacionHasta) dibujarMensaje();
  vaciarEnvioHost();
}

void avisar(String texto){notificacion=texto; notificacionHasta=millis()+2300;}

void descubrirYConectar(){
  DatagramSocket socket=null;
  String ip=null;
  try{
    socket=new DatagramSocket();
    socket.setBroadcast(true);
    byte[] pregunta="HAY_SERVER?".getBytes(StandardCharsets.UTF_8);
    socket.send(new DatagramPacket(pregunta,pregunta.length,InetAddress.getByName("255.255.255.255"),PUERTO_UDP));
    try{
      Enumeration<NetworkInterface> en=NetworkInterface.getNetworkInterfaces();
      while(en!=null&&en.hasMoreElements()){
        NetworkInterface nic=en.nextElement();
        if(!nic.isUp()||nic.isLoopback()) continue;
        for(InterfaceAddress ia:nic.getInterfaceAddresses()) if(ia.getBroadcast()!=null)
          socket.send(new DatagramPacket(pregunta,pregunta.length,ia.getBroadcast(),PUERTO_UDP));
      }
    }catch(Exception ignorada){}
    long limite=System.currentTimeMillis()+1500;
    while(System.currentTimeMillis()<limite){
      DatagramPacket p=new DatagramPacket(new byte[128],128);
      socket.setSoTimeout((int)Math.max(1,limite-System.currentTimeMillis()));
      try{
        socket.receive(p);
        String respuesta=new String(p.getData(),0,p.getLength(),StandardCharsets.UTF_8).trim();
        if(respuesta.equals("ESTOY")){ip=p.getAddress().getHostAddress();break;}
      }catch(SocketTimeoutException fin){break;}
    }
  }catch(Exception e){println("[UDP] "+e.getMessage());}
  finally{if(socket!=null)socket.close();}
  if(ip!=null){
    try{
      c=new Client(this,ip,PUERTO_TCP);
      if(c!=null&&c.active()){
        esServidor=false;myID=1;serverIP=ip;
        textoRed="Cliente Conectado con Exito - "+ip;
        buscando=false;
        thread("recibirDatos");
        return;
      }
    }catch(Exception e){println("[TCP cliente] "+e.getMessage());}
    if(c!=null)try{c.stop();}catch(Exception e){}
  }
  try{
    s=new Server(this,PUERTO_TCP);
    if(s==null||!s.active()) throw new RuntimeException("No se pudo abrir TCP "+PUERTO_TCP);
    esServidor=true;myID=0;serverIP="HOST";
    textoRed="Modo Host Iniciado - esperando segundo jugador";
    buscando=false;
    thread("responderDescubrimiento");
    thread("recibirDatos");
  }catch(Exception e){textoRed="ERROR de red: "+e.getMessage(); buscando=false; myID=-2;}
}

void responderDescubrimiento(){
  DatagramSocket udp=null;
  try{
    udp=new DatagramSocket(null);
    udp.setReuseAddress(true);
    udp.bind(new InetSocketAddress(PUERTO_UDP));
    udp.setSoTimeout(300);
    servidorUDP=udp;
    while(conexionActiva&&esServidor){
      DatagramPacket pedido=new DatagramPacket(new byte[128],128);
      try{
        udp.receive(pedido);
        String str=new String(pedido.getData(),0,pedido.getLength(),StandardCharsets.UTF_8).trim();
        if(str.equals("HAY_SERVER?")&&!clienteConectado&&pantalla==LOBBY){
          byte[] ok="ESTOY".getBytes(StandardCharsets.UTF_8);
          udp.send(new DatagramPacket(ok,ok.length,pedido.getAddress(),pedido.getPort()));
        }
      }catch(SocketTimeoutException e){}
    }
  }catch(Exception e){println("[UDP host] "+e.getMessage());}
  finally{if(udp!=null)udp.close();}
}


void serverEvent(Server servidor,Client nuevo){
  if(!esServidor) return;
  if(remoto==null||!remoto.active()){
    remoto=nuevo;clienteConectado=true;
    textoRed="Cliente Conectado con Exito - "+nuevo.ip();
  }else{
    try{servidor.disconnect(nuevo);}catch(Exception e){}
  }
}


void recibirDatos(){
  while(conexionActiva){
    try{
      if(esServidor){
        if(remoto!=null&&!remoto.active()){
          remoto=null;clienteConectado=false;
          textoRed="Cliente desconectado";
        }
        if(s!=null){
          Client activo=s.available();
          if(activo!=null){
            if(remoto==null){remoto=activo;clienteConectado=true;}
            if(activo!=remoto){try{s.disconnect(activo);}catch(Exception e){} }
            else recibirLineas(activo);
          }
        }
      }else{
        if(c!=null&&c.active())recibirLineas(c);
        else if(c!=null){textoRed="Conexion perdida con el host";}
      }
      Thread.sleep(3);
    }catch(Exception e){
      println("[TCP] "+e.getMessage());
      try{Thread.sleep(25);}catch(Exception ignorada){}
    }
  }
}
void recibirLineas(Client socket){
  
  int n=0;
  while(socket!=null&&socket.available()>0&&n++<250){
    String linea=socket.readStringUntil(10);
    if(linea==null)break;
    synchronized(lineasRecibidas){
      if(lineasRecibidas.size()<2500)lineasRecibidas.add(linea.trim());
    }
  }
}

String trama(int emisor,int codigo,int d1,int d2,int d3,int d4){
  String num=codigo==10?"0010":"000"+codigo; // sin formatter en 10Hz x unidades
  return emisor+" "+num+" "+d1+" "+d2+" "+d3+" "+d4;
}
void enviarCliente(int codigo,int d1,int d2,int d3,int d4){
  if(esServidor||c==null||!c.active())return;
  synchronized(candadoEnvio){c.write(trama(1,codigo,d1,d2,d3,d4)+"\n");}
}
void emitir(int emisor,int codigo,int d1,int d2,int d3,int d4){
  if(!esServidor||s==null||!clienteConectado)return;
  // Nunca cambiamos el formato: siguen siendo 6 enteros por linea.
  synchronized(candadoEnvio){
    envioPendiente.append(trama(emisor,codigo,d1,d2,d3,d4)).append('\n');
  }
}
void vaciarEnvioHost(){
  if(!esServidor||s==null||!clienteConectado){
    synchronized(candadoEnvio){envioPendiente.setLength(0);}
    return;
  }
  synchronized(candadoEnvio){
    if(envioPendiente.length()>0){
      s.write(envioPendiente.toString());
      envioPendiente.setLength(0);
    }
  }
}

class Mensaje {
  int emisor,codigo,d1,d2,d3,d4;
  Mensaje(int[] d){emisor=d[0];codigo=d[1];d1=d[2];d2=d[3];d3=d[4];d4=d[5];}
}

Mensaje interpretar(String linea){
  if(linea==null||linea.length()>130)return null;
  int[] valores=new int[6];int cuenta=0,numero=0,signo=1,inicio=0;
  boolean tieneDigito=false;
  for(int i=0;i<=linea.length();i++){
    char ch=i==linea.length()?' ':linea.charAt(i);
    if(ch==' '){
      if(!tieneDigito||cuenta>=6)return null;
      if(cuenta==1&&i-inicio!=4)return null; 
      valores[cuenta++]=numero*signo;
      numero=0;signo=1;tieneDigito=false;inicio=i+1;
    }else if(ch=='-'&&i==inicio){signo=-1;}
    else if(ch>='0'&&ch<='9'){
      int dig=ch-'0';
      if(numero>(Integer.MAX_VALUE-dig)/10)return null;
      numero=numero*10+dig;tieneDigito=true;
    }else return null;
  }
  if(cuenta!=6||valores[1]<1||valores[1]>10)return null;
  return new Mensaje(valores);
}
void consumirCola(){
  ArrayList<String> pendientes=new ArrayList<String>();
  synchronized(lineasRecibidas){
    int limite=Math.min(1800,lineasRecibidas.size());
    for(int i=0;i<limite;i++) pendientes.add(lineasRecibidas.get(i));
    lineasRecibidas.subList(0,limite).clear();
  }
  for(String linea:pendientes){
    Mensaje m=interpretar(linea);
    if(m==null)continue;
    if(esServidor){
      m.emisor=1;
      procesarSolicitud(m);
    }else procesarConfirmacion(m);
  }
}


void solicitar(int codigo,int d1,int d2,int d3,int d4){
  if(pantalla!=JUGANDO)return;
  if(esServidor)procesarSolicitud(new Mensaje(new int[]{0,codigo,d1,d2,d3,d4}));
  else enviarCliente(codigo,d1,d2,d3,d4);
}
void procesarSolicitud(Mensaje m){
  int quien=m.emisor;
  if(quien<0||quien>1)return;
  if(pantalla==LOBBY){
    if(quien==1&&m.codigo==EVOLVE_ERA&&m.d1==1&&m.d2==0){
      clientePreparado=true;
      textoRed="Cliente Conectado con Exito - ambos pueden comenzar";
    }
    return;
  }
  if(pantalla==GAME_OVER){
    if(m.codigo==EVOLVE_ERA&&m.d1==1&&m.d2==0){
      if(quien==0)revanchaHost=true;else revanchaCliente=true;
      if(revanchaHost&&revanchaCliente)reiniciarServidor();
    }
    return;
  }
  if(pantalla!=JUGANDO)return;
  if(m.codigo==SPAWN_UNIT)aceptarUnidad(quien,m.d1,m.d2);
  else if(m.codigo==BUY_TURRET)aceptarTorre(quien,m.d1,m.d2);
  else if(m.codigo==SELL_TURRET)venderTorre(quien,m.d1);
  else if(m.codigo==EVOLVE_ERA)evolucionar(quien,m.d1);
  else if(m.codigo==SPECIAL_ABILITY)especial(quien,m.d1,m.d2,m.d3);
}
void aceptarUnidad(int owner,int slot,int idPedido){
  if(slot<1||slot>3)return;
  Jugador j=jugadores[owner];
  int coste=COSTOS[j.era-1][slot-1];
  if(j.oro<coste||unidadesDe(owner)>=MAX_UNIDADES)return;
  int id;
  if(owner==0){id=idHost++;if(id>=100000)return;}
  else {
    if(idPedido<=100000||idPedido>999999||idPedido<=idClienteAutorizado||indiceUnidades.containsKey(idPedido))return;
    idClienteAutorizado=idPedido;id=idPedido;
  }
  j.oro-=coste;
  Unidad u=crearUnidad(owner,slot,id,j.era);
  float xSpawn=hallarSpawn(owner,u.ancho);
  u.enReserva=Float.isNaN(xSpawn);
  if(!u.enReserva){u.posicion.x=xSpawn;u.objetivo.set(xSpawn,SUELO);}
  synchronized(listaEntidades){listaEntidades.add(u);indiceUnidades.put(u.id,u);}
  emitir(owner,SPAWN_UNIT,slot,id,0,0);
  emitir(0,UPDATE_POS,id,u.enReserva?-1:round(u.posicion.x),round(SUELO),u.hp);
}
void evolucionar(int owner,int nuevaEra){
  Jugador j=jugadores[owner];
  if(nuevaEra!=j.era+1||nuevaEra>3)return;
  if(j.xp<XP_EVOLUCION[nuevaEra-1]||j.oro<ORO_EVOLUCION[nuevaEra-1])return;
  j.oro-=ORO_EVOLUCION[nuevaEra-1];
  j.era=nuevaEra;
  j.hp=VIDA_BASE[nuevaEra-1];j.maxHp=j.hp;
  emitir(owner,EVOLVE_ERA,nuevaEra,j.hp,0,0);
  publicarBases();
}
void aceptarTorre(int owner,int slot,int tipo){
  if(slot<1||slot>2||tipo<1||tipo>3)return;
  Jugador j=jugadores[owner];
  if(tipo!=j.era||torres[owner][slot-1]!=null)return;
  int costo=COSTO_TORRE[tipo-1];
  if(j.oro<costo)return;
  j.oro-=costo;
  torres[owner][slot-1]=new Torreta(owner,slot,tipo);
  emitir(owner,BUY_TURRET,slot,tipo,0,0);
}
void venderTorre(int owner,int slot){
  if(slot<1||slot>2)return;
  Torreta t=torres[owner][slot-1];
  if(t==null)return;
  int devolución=COSTO_TORRE[t.tipo-1]/2;
  jugadores[owner].oro+=devolución;
  torres[owner][slot-1]=null;
  emitir(owner,SELL_TURRET,slot,devolución,0,0);
}
void especial(int owner,int tipo,int x,int y){
  Jugador j=jugadores[owner];
  if(tipo!=j.era||j.cooldown>0)return;
  // La zona debe estar en el lado enemigo, no en tu propia base.
  x=constrain(x,owner==0?560:140,owner==0?1140:720);
  y=constrain(y,280,(int)SUELO);
  j.cooldown=CD_ESPECIAL;
  emitir(owner,SPECIAL_ABILITY,tipo,x,y,0);
  crearImpacto(x,y,tipo==1?3:2);
  ArrayList<Unidad> blancos=new ArrayList<Unidad>();
  synchronized(listaEntidades){
    for(Unidad u:listaEntidades)if(u.owner!=owner&&!u.enReserva&&u.hp>0&&abs(u.posicion.x-x)<165)blancos.add(u);
  }
  for(Unidad u:blancos)herirUnidad(u,DANIO_ESPECIAL[tipo-1],-10-owner);
  if(abs((owner==0?FRENTE_BASE_DERECHA:FRENTE_BASE_IZQUIERDA)-x)<160)
    herirBase(1-owner,DANIO_ESPECIAL[tipo-1],-10-owner);
}


void procesarConfirmacion(Mensaje m){
  if(m.emisor<0||m.emisor>1)return;
  switch(m.codigo){
  case SPAWN_UNIT:
    if(pantalla!=JUGANDO||m.d1<1||m.d1>3||m.d2<=0||indiceUnidades.containsKey(m.d2))break;
    Unidad u=crearUnidad(m.emisor,m.d1,m.d2,jugadores[m.emisor].era);
    u.enReserva=true; // hasta recibir la posicion 0002 del host
    synchronized(listaEntidades){listaEntidades.add(u);indiceUnidades.put(u.id,u);}
    jugadores[m.emisor].oro=Math.max(0,jugadores[m.emisor].oro-COSTOS[u.era-1][u.tipo-1]);
    break;
  case UPDATE_POS:
    if(m.emisor!=0)break;
    if(m.d1==-1||m.d1==-2){
      Jugador j=jugadores[m.d1==-1?0:1];
      j.oro=m.d2;j.xp=m.d3;j.era=constrain(m.d4,1,3);
    }else {
      Unidad e=indiceUnidades.get(m.d1);
      if(e!=null){
        if(m.d2<0){e.enReserva=true;e.moviendo=false;}
        else{
          if(e.enReserva){e.posicion.set(m.d2,m.d3);e.enReserva=false;}
          e.objetivo.set(m.d2,m.d3);
        }
        e.hp=m.d4;
        if(e.hp<=0)e.muerta=true;
      }
    }
    break;
  case BASE_HP:
    if(m.emisor!=0)break;
    if(pantalla==LOBBY){resetearModelo();pantalla=JUGANDO;}
    jugadores[0].hp=m.d1;jugadores[1].hp=m.d2;
    break;
  case SPAWN_PARTICLE:
    if(m.emisor==0)crearImpacto(m.d1,m.d2,m.d3);
    break;
  case FIN_PARTIDA:
    if(m.emisor==0){ganador=m.d1;pantalla=GAME_OVER;}
    break;
  case BUY_TURRET:
    if(pantalla==JUGANDO&&m.d1>=1&&m.d1<=2&&m.d2>=1&&m.d2<=3){
      torres[m.emisor][m.d1-1]=new Torreta(m.emisor,m.d1,m.d2);
    }
    break;
  case SPECIAL_ABILITY:
    if(pantalla==JUGANDO){
      jugadores[m.emisor].cooldown=CD_ESPECIAL;
      crearImpacto(m.d2,m.d3,m.d1==1?3:2);
    }
    break;
  case EVOLVE_ERA:
    if(pantalla==GAME_OVER&&m.emisor==0&&m.d1==1&&m.d2==500){
      resetearModelo();pantalla=JUGANDO;ganador=-1;
      break;
    }
    if(pantalla==JUGANDO&&m.d1>=2&&m.d1<=3&&m.d1==jugadores[m.emisor].era+1){
      jugadores[m.emisor].era=m.d1;
      jugadores[m.emisor].maxHp=VIDA_BASE[m.d1-1];
      jugadores[m.emisor].hp=m.d2;
    }
    break;
  case ATTACK_EVENT:
    if(pantalla==JUGANDO){
      Unidad atacanteAnim=indiceUnidades.get(m.d1);
      if(atacanteAnim!=null)atacanteAnim.animAtaque=.28f;
      if(m.d3==0){
   
        balaVisualDesdeEvento(m);
        break;
      }
      cerrarProyectilVisual(m);
      if(m.d4==1){
        if(m.d2==0||m.d2==1)jugadores[m.d2].hp=Math.max(0,jugadores[m.d2].hp-m.d3);
      }else {
        Unidad t=indiceUnidades.get(m.d2);
        if(t!=null){t.hp=Math.max(0,t.hp-m.d3); if(t.hp<=0)t.muerta=true;}
      }
    }
    break;
  case SELL_TURRET:
    if(pantalla==JUGANDO&&m.d1>=1&&m.d1<=2){
      torres[m.emisor][m.d1-1]=null;
    }
    break;
  }
}


void balaVisualDesdeEvento(Mensaje m){
  if(m.d1<=-10)return; 
  Unidad atacante=indiceUnidades.get(m.d1);
  int owner;
  PVector inicio;
  PVector vel;
  if(atacante!=null){
    if(atacante.rango<90)return; 
    owner=atacante.owner;
    inicio=new PVector(atacante.posicion.x,ALTURA_DISPARO);
    vel=new PVector(owner==0?430:-430,0);
  }else if(m.d1>=-4&&m.d1<=-1){
    owner=m.d1>=-2?0:1;
    int slot=owner==0?-m.d1:-m.d1-2;
    if(slot<1||slot>2)return;
    inicio=new PVector(owner==0?TORRE_IZQUIERDA_X:TORRE_DERECHA_X,alturaTorre(slot));
    Unidad objetivo=indiceUnidades.get(m.d2);
    if(objetivo==null)return;
    vel=new PVector(objetivo.posicion.x-inicio.x,objetivo.posicion.y-objetivo.alto*.45f-inicio.y);
    if(vel.magSq()<1)vel.set(owner==0?1:-1,0);
    vel.normalize();vel.mult(430);
  }else return;
  Proyectil b=new Proyectil(owner,m.d1,inicio,vel,0);
  b.objetivoID=m.d4==1?-10-m.d2:m.d2;
  b.ttl=3;
  listaProyectiles.add(b);
}
void cerrarProyectilVisual(Mensaje m){
  if(m.d1<=-10)return;
  int objetivo=m.d4==1?-10-m.d2:m.d2;
  for(int i=0;i<listaProyectiles.size();i++){
    Proyectil p=listaProyectiles.get(i);
    if(p.idAtacante==m.d1&&p.objetivoID==objetivo){
      listaProyectiles.remove(i);
      break;
    }
  }
}


void iniciarPartidaHost(){
  if(!esServidor||!clienteConectado||!clientePreparado||pantalla!=LOBBY){avisar("P2 debe conectarse y pulsar COMENZAR PARTIDA");return;}
  resetearModelo();
  pantalla=JUGANDO;
  publicarBases(); 
  ultimoSync=millis();
}
void resetearModelo(){
  synchronized(listaEntidades){listaEntidades.clear();indiceUnidades.clear();}
  listaProyectiles.clear();listaParticulas.clear();
  synchronized(candadoEnvio){envioPendiente.setLength(0);}
  jugadores[0]=new Jugador(0);jugadores[1]=new Jugador(1);
  torres=new Torreta[2][2];
  idHost=1;idClienteAutorizado=100000;
  acumuladorOro=0;ganador=-1;
  revanchaHost=false;revanchaCliente=false;
  ultimoSync=millis();
}
void pedirRevancha(){
  if(pantalla!=GAME_OVER)return;
  if(esServidor){
    revanchaHost=true;avisar("Revancha solicitada. Esperando al rival...");
    if(revanchaCliente)reiniciarServidor();
  }else{
    enviarCliente(EVOLVE_ERA,1,0,0,0);
    avisar("Revancha solicitada. Esperando al host...");
  }
}
void reiniciarServidor(){
  resetearModelo();pantalla=JUGANDO;
  emitir(0,EVOLVE_ERA,1,500,0,0); 
  publicarBases();
}
int siguienteUnidadCliente=100001;
void pedirUnidad(int t){
  if(t<1||t>3)return;
  int id=esServidor?0:siguienteUnidadCliente++;
  solicitar(SPAWN_UNIT,t,id,0,0);
}
void pedirTorre(int slot){solicitar(BUY_TURRET,slot,jugadores[myID].era,0,0);}
void pedirEvolucion(){
  Jugador j=jugadores[myID];
  if(j.era<3)solicitar(EVOLVE_ERA,j.era+1,VIDA_BASE[j.era],0,0);
}
void pedirEspecial(int x,int y){
  solicitar(SPECIAL_ABILITY,jugadores[myID].era,x,y,0);
}


void simularServidor(float dt){
  if(!clienteConectado)return; 
  acumuladorOro+=dt;
  while(acumuladorOro>=1){
    jugadores[0].oro+=2;jugadores[1].oro+=2;
    acumuladorOro-=1;
  }
  for(Jugador j:jugadores)j.cooldown=Math.max(0,j.cooldown-dt);
  synchronized(listaEntidades){
    for(Unidad u:listaEntidades)if(!u.muerta&&!u.enReserva)u.actualizarServidor(dt);
    for(int i=listaEntidades.size()-1;i>=0;i--){
      Unidad u=listaEntidades.get(i);
      if(u.muerta){indiceUnidades.remove(u.id);listaEntidades.remove(i);}
    }
  }
  liberarReservas();
  for(int p=0;p<2;p++)for(int t=0;t<2;t++)if(torres[p][t]!=null)torres[p][t].actualizarServidor(dt);
  for(int i=listaProyectiles.size()-1;i>=0;i--){
    Proyectil b=listaProyectiles.get(i);
    b.actualizarServidor(dt);
    if(b.muerto)listaProyectiles.remove(i);
  }
  if(millis()-ultimoSync>=TX_SYNC_MS){
    ultimoSync=millis();
    publicarPosiciones();
    publicarBases();
  }
  for(int i=0;i<2;i++)if(jugadores[i].hp<=0){
    ganador=1-i;pantalla=GAME_OVER;
    emitir(0,FIN_PARTIDA,ganador,0,0,0);
    break;
  }
}
void actualizarReplica(float dt){
  synchronized(listaEntidades){
    for(Unidad u:listaEntidades){
      if(u.enReserva)continue;
      u.moviendo=abs(u.objetivo.x-u.posicion.x)>1.3f;
      u.animAtaque=Math.max(0,u.animAtaque-dt);
      u.posicion.x=lerp(u.posicion.x,u.objetivo.x,Math.min(1,dt*12));
      u.posicion.y=lerp(u.posicion.y,u.objetivo.y,Math.min(1,dt*12));
    }
    for(int i=listaEntidades.size()-1;i>=0;i--)if(listaEntidades.get(i).muerta){
      indiceUnidades.remove(listaEntidades.get(i).id);listaEntidades.remove(i);
    }
  }
  
  for(int i=listaProyectiles.size()-1;i>=0;i--){
    Proyectil b=listaProyectiles.get(i);
    b.posicion.x+=b.velocidad.x*dt;
    b.posicion.y+=b.velocidad.y*dt;
    b.ttl-=dt;
    if(b.ttl<=0)listaProyectiles.remove(i);
  }
  for(Jugador j:jugadores){
    j.cooldown=Math.max(0,j.cooldown-dt);
}
}
void publicarBases(){emitir(0,BASE_HP,jugadores[0].hp,jugadores[1].hp,0,0);}
void publicarPosiciones(){
  synchronized(listaEntidades){
    for(Unidad u:listaEntidades){
      emitir(0,UPDATE_POS,u.id,u.enReserva?-1:round(u.posicion.x),round(u.posicion.y),Math.max(0,u.hp));
    }
  }
  emitir(0,UPDATE_POS,-1,jugadores[0].oro,jugadores[0].xp,jugadores[0].era);
  emitir(0,UPDATE_POS,-2,jugadores[1].oro,jugadores[1].xp,jugadores[1].era);
}
float hallarSpawn(int owner,float ancho){
  
  synchronized(listaEntidades){
    for(int k=0;k<=8;k++){
      float x=owner==0?SPAWN_IZQUIERDA+k*5.5f:SPAWN_DERECHA-k*5.5f;
      if(owner==0&&x+ancho/2>=SITIO_IZQUIERDA-6)continue;
      if(owner==1&&x-ancho/2<=SITIO_DERECHA+6)continue;
      boolean libre=true;
      for(Unidad u:listaEntidades){
        if(u.muerta||u.enReserva)continue;
        if(Math.abs(x-u.posicion.x)<(ancho+u.ancho)*.5f+5){libre=false;break;}
      }
      if(libre)return x;
    }
  }
  return Float.NaN; 
}
void liberarReservas(){
  synchronized(listaEntidades){
    for(int owner=0;owner<2;owner++){
      for(Unidad u:listaEntidades){
        if(u.owner!=owner||!u.enReserva||u.muerta)continue;
        float x=hallarSpawn(owner,u.ancho);
        if(!Float.isNaN(x)){
          u.posicion.set(x,SUELO);u.objetivo.set(x,SUELO);
          u.enReserva=false;u.moviendo=false;
          emitir(0,UPDATE_POS,u.id,round(x),round(SUELO),u.hp);
        }
       
        break;
      }
    }
  }
}
int unidadesDe(int owner){
  int n=0; synchronized(listaEntidades){for(Unidad u:listaEntidades)if(u.owner==owner&&!u.muerta)n++;}
  return n;
}


Unidad crearUnidad(int owner,int tipo,int id,int era){
  if(tipo==1)return new UnidadCuerpo(owner,tipo,id,era);
  if(tipo==2)return new UnidadDistancia(owner,tipo,id,era);
  return new UnidadPesada(owner,tipo,id,era);
}
Unidad enemigoMasCercano(Unidad atacante){
  Unidad elegido=null;float dist=Float.MAX_VALUE;
  for(Unidad u:listaEntidades){
    if(u.owner==atacante.owner||u.muerta||u.enReserva)continue;
    float dx=(u.posicion.x-atacante.posicion.x)*(atacante.owner==0?1:-1);
    if(dx < -12)continue;
    if(dx<dist){dist=dx;elegido=u;}
  }
  return elegido;
}
Unidad enemigoEnRango(float x,float y,int owner,float alcance){
  Unidad elegido=null;float d=alcance;
  synchronized(listaEntidades){
    for(Unidad u:listaEntidades){
      if(u.owner==owner||u.muerta||u.enReserva)continue;
      float dx=abs(u.posicion.x-x);
      if(dx<d){d=dx;elegido=u;}
    }
  }
  return elegido;
}

float hueco(Unidad a,Unidad b){
  return abs(a.posicion.x-b.posicion.x)-(a.ancho+b.ancho)*0.5f;
}
float avancePosible(Unidad u,float deseo){
  float propuesta=u.posicion.x+deseo;
  for(Unidad v:listaEntidades){
    if(v==u||v.muerta||v.enReserva)continue;
    if(u.owner==0&&v.posicion.x<u.posicion.x-2)continue;
    if(u.owner==1&&v.posicion.x>u.posicion.x+2)continue;
    float separacion=(u.ancho+v.ancho)*.5f+4;
    if(u.owner==0){
      if(v.posicion.x-u.posicion.x<=separacion)propuesta=Math.min(propuesta,u.posicion.x);
      else propuesta=Math.min(propuesta,v.posicion.x-separacion);
    }else{
      if(u.posicion.x-v.posicion.x<=separacion)propuesta=Math.max(propuesta,u.posicion.x);
      else propuesta=Math.max(propuesta,v.posicion.x+separacion);
    }
  }
  
  return u.owner==0?Math.min(propuesta,SITIO_DERECHA):Math.max(propuesta,SITIO_IZQUIERDA);
}

void disparar(int owner,int atacanteID,PVector origen,Unidad objetivo,int daño){
  PVector vel;
  if(atacanteID>0){
   
    origen.y=ALTURA_DISPARO;
    vel=new PVector(owner==0?430:-430,0);
  }else{
 
    float dx=objetivo.posicion.x-origen.x;
    float dy=(objetivo.posicion.y-objetivo.alto*.45f)-origen.y;
    vel=new PVector(dx,dy);
    if(vel.magSq()<1)vel.set(owner==0?1:-1,0);
    vel.normalize();vel.mult(430);
  }
  listaProyectiles.add(new Proyectil(owner,atacanteID,origen,vel,daño));

  emitir(0,ATTACK_EVENT,atacanteID,objetivo.id,0,0);
}
boolean segmentoContraCaja(float ax,float ay,float bx,float by,Unidad u){
  
  float x0=u.posicion.x-u.ancho*.5f,x1=u.posicion.x+u.ancho*.5f;
  float y0=u.posicion.y-u.alto,y1=u.posicion.y;
  float dx=bx-ax,dy=by-ay,tMin=0,tMax=1;
  if(Math.abs(dx)<0.00001f){if(ax<x0||ax>x1)return false;}
  else{
    float a=(x0-ax)/dx,b=(x1-ax)/dx;
    if(a>b){float tmp=a;a=b;b=tmp;}
    tMin=Math.max(tMin,a);tMax=Math.min(tMax,b);
    if(tMin>tMax)return false;
  }
  if(Math.abs(dy)<0.00001f){if(ay<y0||ay>y1)return false;}
  else{
    float a=(y0-ay)/dy,b=(y1-ay)/dy;
    if(a>b){float tmp=a;a=b;b=tmp;}
    tMin=Math.max(tMin,a);tMax=Math.min(tMax,b);
    if(tMin>tMax)return false;
  }
  return true;
}
void herirUnidad(Unidad u,int daño,int atacanteId){
  herirUnidadEn(u,daño,atacanteId,u.posicion.x,u.posicion.y-u.alto*.5f);
}
void herirUnidadEn(Unidad u,int daño,int atacanteId,float impactoX,float impactoY){
  if(u.muerta||daño<=0)return;
  int aplicado=Math.min(u.hp,daño);
  u.hp-=aplicado;
  int owner=(atacanteId<=-10 ? -10-atacanteId : propietarioAtacante(atacanteId));
  if(owner>=0&&owner<=1){
    jugadores[owner].xp+=aplicado; 
  }
  emitir(0,ATTACK_EVENT,atacanteId,u.id,aplicado,0);
  if(u.hp<=0){
    u.muerta=true;
    if(owner>=0&&owner<=1){
    
      int botin=Math.round(COSTOS[u.era-1][u.tipo-1]*.75f)+BONUS_ORO_ERA[jugadores[owner].era-1];
      jugadores[owner].oro+=Math.max(10,botin);
    }
    crearImpacto(round(impactoX),round(impactoY),2);
  }else crearImpacto(round(impactoX),round(impactoY),1);
}
int propietarioAtacante(int atacanteId){
  if(atacanteId==0)return 0; 
  if(atacanteId==-1||atacanteId==-2)return 0;
  if(atacanteId==-3||atacanteId==-4)return 1;
  Unidad u=indiceUnidades.get(atacanteId);

  if(u!=null)return u.owner;
  return atacanteId>=100000?1:atacanteId>0?0:-1;
}
void herirBase(int owner,int daño,int idAtaque){
  if(jugadores[owner].hp<=0)return;
  int aplicado=Math.min(jugadores[owner].hp,daño);
  jugadores[owner].hp-=aplicado;
  int atacante=propietarioAtacante(idAtaque);
  if(idAtaque<=-10)atacante=-10-idAtaque;
  if(atacante>=0&&atacante<=1)jugadores[atacante].xp+=aplicado;
  emitir(0,ATTACK_EVENT,idAtaque,owner,aplicado,1);
  publicarBases();
  
  crearImpacto(round(owner==0?FRENTE_BASE_IZQUIERDA:FRENTE_BASE_DERECHA),round(ALTURA_DISPARO),1);
}
void crearImpacto(int x,int y,int tipo){
  if(esServidor)emitir(0,SPAWN_PARTICLE,x,y,tipo,0);
  int c=tipo==3?color(255,160,40):tipo==2?color(255,85,35):color(255,225,90);
  int n=tipo==1?11:32;
  for(int i=0;i<n;i++){
    float ang=random(TWO_PI),vel=random(35,180);
    listaParticulas.add(new Particula(x,y,new PVector(cos(ang)*vel,sin(ang)*vel-30),random(.35f,.85f),c));
  }
}
void actualizarParticulas(float dt){
  for(int i=listaParticulas.size()-1;i>=0;i--){
    Particula p=listaParticulas.get(i);p.actualizar(dt);
    if(p.vida<=0)listaParticulas.remove(i);
  }
  if(listaParticulas.size()>500)listaParticulas.subList(0,listaParticulas.size()-500).clear();
}
void dibujarParticulas(){for(Particula p:listaParticulas)p.dibujar();}


void dibujarLobby(){
  background(20,28,43);
  noStroke();
  for(int i=0;i<80;i++){
    fill(255,255,255,12+i%4*3);
    ellipse((i*213)%W,(i*89)%H,3,3);
  }
  fill(33,47,68);rect(174,120,930,480,22);
  stroke(118,172,220);strokeWeight(2);noFill();rect(174,120,930,480,22);noStroke();
  textAlign(CENTER,CENTER);
  fill(255,207,120);textSize(54);text("AGE OF WAR 1V1",W/2,220);
  fill(227);textSize(27);text("MULTIJUGADOR LAN",W/2,269);
  fill(155,211,248);textSize(19);text(textoRed,W/2,348);
  fill(210);textSize(15);
  String quien=myID==-1?"DETECTANDO ROL":esServidor?"JUGADOR 1 · HOST":"JUGADOR 2 · CLIENTE";
  text(quien,W/2,383);
  dibujarBoton(485,438,310,68,"COMENZAR PARTIDA", esServidor?"Esperar que P2 este preparado":listoLocal?"Listo; esperando al host":"Avisar al host: listo",(esServidor&&clienteConectado&&clientePreparado)||(!esServidor&&myID==1));
  fill(165,190,213);textSize(13);
  text("Abrí el mismo sketch en dos PCs · UDP 8888 / TCP 12345 · Sin ingresar IP",W/2,558);
  text("Si ambos equipos inician a la vez, abrí el host primero y despues el cliente",W/2,580);
}
void dibujarCampo(){
  background(143,196,228);
  if(fondoOriginal!=null)image(fondoOriginal,0,0,W,608);
  else if(fondoCache!=null)image(fondoCache,0,0);
  noStroke();fill(102,96,69,230);rect(0,SUELO,W,115);
  stroke(184,151,100);strokeWeight(3);line(0,SUELO,W,SUELO);noStroke();
  dibujarBase(0);dibujarBase(1);
  for(int p=0;p<2;p++)for(int t=0;t<2;t++)if(torres[p][t]!=null)torres[p][t].dibujar();
  synchronized(listaEntidades){for(Unidad u:listaEntidades)u.dibujar();}
  for(Proyectil b:listaProyectiles)b.dibujar();
}
void dibujarBase(int owner){
  Jugador j=jugadores[owner];
  float x=owner==0?BASE_IZQUIERDA_X:BASE_DERECHA_X;
  PImage im=imagenBase[j.era-1];
  pushMatrix();translate(x,SUELO);
  if(owner==1)scale(-1,1);
  if(im!=null)image(im,-BASE_ANCHO*.5f,-BASE_ALTO,BASE_ANCHO,BASE_ALTO);
  else{
    fill(j.era==1?color(96,88,67):j.era==2?color(130,122,122):color(45,85,116));
    stroke(34);strokeWeight(3);
    rect(-BASE_ANCHO*.5f+5,-BASE_ALTO+5,BASE_ANCHO-10,BASE_ALTO-5,9);
    noStroke();fill(235,173,85);rect(-55,-112,45,112);rect(16,-112,37,112);
  }
  popMatrix();
}
void dibujarSaludBases(){
  // HUD flotante independiente del fondo, SIN transparencia y en primer plano.
  for(int owner=0;owner<2;owner++){
    Jugador j=jugadores[owner];
    float x=owner==0?94:1186;
    noStroke();fill(12,23,36,245);rect(x-81,80,162,54,9);
    fill(255);textAlign(CENTER,CENTER);textSize(13);
    text("BASE P"+(owner+1)+"  "+Math.max(0,j.hp)+" / "+j.maxHp,x,95);
    fill(45,53,64);rect(x-73,111,146,13,4);
    fill(owner==0?color(67,221,111):color(243,108,95));
    rect(x-71,113,142*constrain(j.hp/(float)Math.max(1,j.maxHp),0,1),9,3);
  }
}
void dibujarHUD(){
  fill(17,25,40,235);noStroke();rect(0,0,W,61);
  Jugador a=jugadores[0],b=jugadores[1];
  fill(240);textAlign(LEFT,CENTER);textSize(17);
  text("P1  Oro: "+a.oro+"   XP: "+a.xp+"   Era: "+a.era,18,25);
  textAlign(RIGHT,CENTER);text("P2  Oro: "+b.oro+"   XP: "+b.xp+"   Era: "+b.era,1260,25);
  fill(220,189,109);textAlign(CENTER,CENTER);textSize(14);text(ERA_NOMBRE[jugadores[Math.max(0,myID)].era-1],W/2,22);
  fill(17,25,40,245);rect(0,609,W,111);
  Jugador mio=jugadores[Math.max(0,myID)];
  int era=mio.era-1;
  for(int i=0;i<3;i++)
    dibujarBoton(10+i*132,629,126,74,(i+1)+" · "+NOMBRES[era][i],COSTOS[era][i]+" oro",mio.oro>=COSTOS[era][i]);
  for(int i=0;i<2;i++)
    dibujarBoton(413+i*112,629,106,74,"TORRE "+(i+1),COSTO_TORRE[era]+" oro",torres[Math.max(0,myID)][i]==null&&mio.oro>=COSTO_TORRE[era]);
  String siguiente=mio.era==3?"MAX ERA":"ERA "+(mio.era+1);
  String requisitos=mio.era==3?"COMPLETA":XP_EVOLUCION[mio.era]+"xp / "+ORO_EVOLUCION[mio.era]+" oro";
  dibujarBoton(643,629,129,74,siguiente,requisitos,mio.era<3&&mio.xp>=XP_EVOLUCION[mio.era]&&mio.oro>=ORO_EVOLUCION[mio.era]);
  dibujarBoton(780,629,158,74,"ESPECIAL",mio.cooldown>0?nf(mio.cooldown,0,1)+" s":"LISTO",mio.cooldown<=0);
  dibujarBoton(948,629,155,74,"VENDER T1","50% del costo",torres[Math.max(0,myID)][0]!=null);
  dibujarBoton(1112,629,155,74,"VENDER T2","50% del costo",torres[Math.max(0,myID)][1]!=null);
  int esperando=0;
  synchronized(listaEntidades){for(Unidad u:listaEntidades)if(u.owner==Math.max(0,myID)&&u.enReserva&&!u.muerta)esperando++;}
  fill(222);textAlign(CENTER,CENTER);textSize(13);
  String ayuda="1 / 2 / 3: unidades · Q/W: torres · Z/X: vender · E: evolucionar · S: especial";
  text(esperando>0?"REFUERZOS EN BASE: "+esperando+" | "+ayuda:ayuda,W/2,608);
}
void dibujarBoton(float x,float y,float w,float h,String tit,String sub,boolean habilitado){
  boolean hover=mouseX>=x&&mouseX<=x+w&&mouseY>=y&&mouseY<=y+h;
  fill(habilitado?(hover?color(62,125,166):color(46,92,131)):color(57,63,72));
  stroke(habilitado?color(133,205,248):color(91,95,101));strokeWeight(1.5f);
  rect(x,y,w,h,9);noStroke();
  fill(habilitado?255:178);textAlign(CENTER,CENTER);
  textSize(tit.length()>15?12:15);text(tit,x+w*.5f,y+h*.36f);
  textSize(11);fill(habilitado?color(255,224,151):color(152));
  text(sub,x+w*.5f,y+h*.73f);
}
void dibujarFinal(){
  fill(4,8,14,215);noStroke();rect(0,0,W,H);
  fill(29,40,55);rect(337,191,606,346,22);
  fill(255,220,154);textAlign(CENTER,CENTER);textSize(49);
  text(ganador==myID?"VICTORIA":"DERROTA",W/2,275);
  fill(233);textSize(20);text("Gano el jugador "+(ganador+1),W/2,342);
  dibujarBoton(489,395,302,85,"JUGAR DE NUEVO","Ambos deben aceptar · R",true);
  fill(174,200,216);textSize(13);text("La conexion TCP permanece abierta",W/2,520);
}
void dibujarMensaje(){
  fill(20,34,49,231);noStroke();rect(300,72,680,35,8);
  fill(255);textAlign(CENTER,CENTER);textSize(15);text(notificacion,W/2,89);
}
void keyPressed(){
  if(pantalla==GAME_OVER){if(key=='r'||key=='R')pedirRevancha();return;}
  if(pantalla!=JUGANDO)return;
  if(key>='1'&&key<='3')pedirUnidad(key-'0');
  else if(key=='q'||key=='Q')pedirTorre(1);
  else if(key=='w'||key=='W')pedirTorre(2);
  else if(key=='z'||key=='Z')solicitar(SELL_TURRET,1,0,0,0);
  else if(key=='x'||key=='X')solicitar(SELL_TURRET,2,0,0,0);
  else if(key=='e'||key=='E')pedirEvolucion();
  else if(key=='s'||key=='S'||key==' ')pedirEspecial(myID==0?948:332,(int)SUELO);
}
void mousePressed(){
  if(pantalla==LOBBY){
    if(enRect(485,438,310,68)){
      if(esServidor)iniciarPartidaHost();
      else if(myID==1){listoLocal=true;enviarCliente(EVOLVE_ERA,1,0,0,0);avisar("Listo. Esperando que el host comience...");}
    }
    return;
  }
  if(pantalla==GAME_OVER){if(enRect(489,395,302,85))pedirRevancha();return;}
  if(pantalla!=JUGANDO)return;
  if(mouseY>=629&&mouseY<=703){
    for(int i=0;i<3;i++)if(enRect(10+i*132,629,126,74)){pedirUnidad(i+1);return;}
    for(int i=0;i<2;i++)if(enRect(413+i*112,629,106,74)){pedirTorre(i+1);return;}
    if(enRect(643,629,129,74)){pedirEvolucion();return;}
    if(enRect(780,629,158,74)){pedirEspecial(myID==0?930:350,(int)SUELO);return;}
    if(enRect(948,629,155,74)){solicitar(SELL_TURRET,1,0,0,0);return;}
    if(enRect(1112,629,155,74)){solicitar(SELL_TURRET,2,0,0,0);return;}
  }
  if(mouseY>150&&mouseY<SUELO&&jugadores[myID].cooldown<=0)pedirEspecial(mouseX,mouseY);
}
boolean enRect(float x,float y,float w,float h){
  return mouseX>=x&&mouseX<=x+w&&mouseY>=y&&mouseY<=y+h;
}

class Jugador {
  int id,oro=ORO_INICIAL,xp=0,era=1;
  int hp=500,maxHp=500;
  float cooldown=0;
  Jugador(int id){this.id=id;}
}
abstract class Unidad {
  int id,owner,era,tipo,hp,hpMax,danio;
  float rango,velocidad,periodo,tiempoAtaque,ancho,alto;
  PVector posicion,objetivo,vel=new PVector();
  float animAtaque=0;
  boolean muerta=false,moviendo=false,enReserva=false;
  Unidad(int o,int t,int i,int e){
    owner=o;tipo=t;id=i;era=e;
    hp=hpMax=VIDAS[e-1][t-1];danio=DANIOS[e-1][t-1];
    rango=RANGOS[e-1][t-1];velocidad=VELOCIDADES[e-1][t-1];periodo=CICLOS[e-1][t-1];
    ancho=ANCHOS[e-1][t-1];alto=ALTOS[e-1][t-1];
    posicion=new PVector(o==0?SPAWN_IZQUIERDA:SPAWN_DERECHA,SUELO);
    objetivo=posicion.copy();
   
  }
  void actualizarServidor(float dt){
    if(enReserva)return;
    tiempoAtaque=Math.max(0,tiempoAtaque-dt);
    animAtaque=Math.max(0,animAtaque-dt);
    Unidad enemigo=enemigoMasCercano(this);
    moviendo=false;
   
    if(enemigo!=null&&hueco(this,enemigo)<=rango){
      if(tiempoAtaque<=0){atacar(enemigo);tiempoAtaque=periodo;animAtaque=.28f;}
      return;
    }
   
    float frente=owner==0?FRENTE_BASE_DERECHA:FRENTE_BASE_IZQUIERDA;
    float distanciaBase=Math.max(0,abs(frente-posicion.x)-ancho*.5f);
   
    float alcanceBase=tipo==3?Math.min(rango,20.0f):rango;
    if(distanciaBase<=alcanceBase+3){
      if(tiempoAtaque<=0){atacarBase();tiempoAtaque=periodo;animAtaque=.28f;}
      return;
    }
    float dir=owner==0?1:-1;
    float nuevo=avancePosible(this,dir*velocidad*dt);
    moviendo=abs(nuevo-posicion.x)>0.02f;
    posicion.x=nuevo;
    vel.set(dir*(moviendo?velocidad:0),0);
  }
  void atacar(Unidad victima){
    if(rango>90){
      PVector origen=new PVector(posicion.x,posicion.y-alto*.58f);
      disparar(owner,id,origen,victima,danio);
    }else herirUnidad(victima,danio,id);
  }
  void atacarBase(){
    if(tipo==3){
      
      herirBase(1-owner,danio,id);
    }else if(rango>90){
      PVector origen=new PVector(posicion.x,ALTURA_DISPARO);
      listaProyectiles.add(new Proyectil(owner,id,origen,new PVector(owner==0?430:-430,0),danio));
      emitir(0,ATTACK_EVENT,id,1-owner,0,1);
    }else herirBase(1-owner,danio,id);
  }
  void dibujar(){
    if(muerta||enReserva)return;
    float x=posicion.x,y=posicion.y;
    String accion=animAtaque>0?"attack":moviendo?"walk":"idle";
    PImage[] fotogramas=animaciones.get((era-1)+":"+(tipo-1)+":"+accion);
    PImage sprite=null;
    if(fotogramas!=null&&fotogramas.length>0){
      int lapso=accion.equals("attack")?70:accion.equals("walk")?90:160;
      sprite=fotogramas[(millis()/lapso+id)%fotogramas.length];
    }
    if(sprite==null){
      PImage[] alternativa=animaciones.get((era-1)+":"+(tipo-1)+":walk");
      if(alternativa==null||alternativa.length==0)alternativa=animaciones.get((era-1)+":"+(tipo-1)+":attack");
      if(alternativa!=null&&alternativa.length>0)sprite=alternativa[0];
    }
    if(sprite==null)sprite=spritesSimples[era-1][tipo-1];
    float dibujoAncho=ancho*escalaVisual[era-1][tipo-1];
    pushMatrix();translate(x,y);if(owner==1)scale(-1,1);
    if(sprite!=null)image(sprite,-dibujoAncho*.5f,-alto,dibujoAncho,alto);
    else {fill(80,70,50);rect(-ancho/2,-alto,ancho,alto);}
    popMatrix();
    float vidaAncho=Math.max(23,ancho);
    noStroke();fill(28,35,37,215);rect(x-vidaAncho/2,y-alto-15,vidaAncho,6,2);
    fill(owner==0?color(57,227,108):color(249,96,95));
    rect(x-vidaAncho/2,y-alto-15,vidaAncho*max(0,hp)/(float)hpMax,6,2);
  }
}
class UnidadCuerpo extends Unidad {UnidadCuerpo(int o,int t,int i,int e){super(o,t,i,e);}}
class UnidadDistancia extends Unidad {UnidadDistancia(int o,int t,int i,int e){super(o,t,i,e);}}
class UnidadPesada extends Unidad {UnidadPesada(int o,int t,int i,int e){super(o,t,i,e);}}

class Proyectil {
  int owner,idAtacante,danio;
  int objetivoID=-999; 
  PVector posicion,velocidad;
  boolean muerto=false;
  float ttl=3;
  Proyectil(int o,int id,PVector pos,PVector vel,int daño){
    owner=o;idAtacante=id;posicion=pos.copy();velocidad=vel.copy();danio=daño;
  }
  void actualizarServidor(float dt){
    float viejaX=posicion.x,viejaY=posicion.y;
    posicion.x+=velocidad.x*dt;
    posicion.y+=velocidad.y*dt;
    ttl-=dt;
    Unidad impacto=null;
    synchronized(listaEntidades){
      for(Unidad u:listaEntidades)if(u.owner!=owner&&!u.muerta&&!u.enReserva&&segmentoContraCaja(viejaX,viejaY,posicion.x,posicion.y,u)){
        impacto=u;break;
      }
    }
    if(impacto!=null){
      float bordeImpacto=owner==0?impacto.posicion.x-impacto.ancho*.5f:impacto.posicion.x+impacto.ancho*.5f;
      float xImpacto=constrain(bordeImpacto,Math.min(viejaX,posicion.x),Math.max(viejaX,posicion.x));
      herirUnidadEn(impacto,danio,idAtacante,xImpacto,posicion.y);
      muerto=true;return;
    }
    float xBase=owner==0?FRENTE_BASE_DERECHA:FRENTE_BASE_IZQUIERDA;
    if(owner==0?posicion.x>=xBase:posicion.x<=xBase){
      herirBase(1-owner,danio,idAtacante);muerto=true;return;
    }
    if(ttl<=0||posicion.x<0||posicion.x>W||posicion.y>H||posicion.y<50)muerto=true;
  }
  void dibujar(){
    if(spriteBala!=null){image(spriteBala,posicion.x-9,posicion.y-5,18,10);}
    else {noStroke();fill(255,226,98);ellipse(posicion.x,posicion.y,9,9);}
  }
}
class Torreta {
  int owner,slot,tipo;
  PVector posicion;
  float cd=0;
  Torreta(int o,int s,int t){
    owner=o;slot=s;tipo=t;
    posicion=new PVector(o==0?TORRE_IZQUIERDA_X:TORRE_DERECHA_X,alturaTorre(s));
  }
  void actualizarServidor(float dt){
    cd-=dt;if(cd>0)return;
    Unidad objetivo=enemigoEnRango(posicion.x,posicion.y,owner,RANGO_TORRE[tipo-1]);
    if(objetivo==null)return;
    int atacante=owner==0?-slot:-slot-2;
    disparar(owner,atacante,posicion,objetivo,DANIO_TORRE[tipo-1]);
    cd=Math.max(.4f,1.35f-tipo*.2f);
  }
  void dibujar(){
    PImage img=imagenTorre[tipo-1];
    pushMatrix();translate(posicion.x,posicion.y);
    if(owner==1)scale(-1,1);
    if(img!=null)image(img,-34,-38,68,50);
    else{
      stroke(19,25,33);strokeWeight(2);fill(110,115,125);rect(-24,-24,48,25,6);
      rect(0,-23,36,10,4);noStroke();
    }
    popMatrix();
  }
}
class Particula {
  PVector posicion,velocidad;
  float vida,vidaInicial;
  int col;
  Particula(float x,float y,PVector v,float t,int c){posicion=new PVector(x,y);velocidad=v;vida=vidaInicial=t;col=c;}
  void actualizar(float dt){posicion.x+=velocidad.x*dt;posicion.y+=velocidad.y*dt;velocidad.y+=210*dt;vida-=dt;}
  void dibujar(){noStroke();fill(red(col),green(col),blue(col),255*constrain(vida/vidaInicial,0,1));
    ellipse(posicion.x,posicion.y,5,5);}
}


void generarDibujos(){
  for(int era=0;era<3;era++)for(int tipo=0;tipo<3;tipo++){
    escalaVisual[era][tipo]=1.0f; // nunca invisibilizar el fallback por ancho 0
    PGraphics g=createGraphics(94,120);g.beginDraw();g.clear();
    g.noStroke();
    int col=era==0?color(132,91,53):era==1?color(115,122,137):color(71,164,201);
    g.fill(col);g.ellipse(47,40,26+tipo*7,27+tipo*6);
    g.rect(32-tipo*5,52,30+tipo*10,42+tipo*8,7);
    g.stroke(35);g.strokeWeight(5);g.line(36,94,30,112);g.line(58,94,66,112);
    g.line(31,62,18,81);g.line(61,62,79,81);
    g.endDraw();spritesSimples[era][tipo]=g;
  }
  PGraphics b=createGraphics(25,18);b.beginDraw();b.clear();b.noStroke();b.fill(255,210,90);b.ellipse(12,9,16,9);b.endDraw();spriteBala=b;
}
void generarFondo(){
  PGraphics g=createGraphics(W,608);
  g.beginDraw();g.background(143,196,228);g.noStroke();
  g.fill(177,206,188);g.ellipse(260,400,900,400);g.ellipse(1150,390,800,360);
  g.fill(94,151,115);g.rect(0,468,W,140);
  g.endDraw();fondoCache=g;
}
void cargarOriginales(){
  File directorio=new File(dataPath("original"));
  if(!directorio.isDirectory())return;
  fondoOriginal=loadOriginal("background.png");
  String[] eras={"cave","knight","future"}, clases={"melee","range","tank"};
  for(int e=0;e<3;e++){
    imagenBase[e]=loadOriginal("bases/"+eras[e]+"/base/base.png");
    imagenTorre[e]=primerPng("bases/"+eras[e]+"/turret_1/","attack");
    for(int t=0;t<3;t++){
      String ruta="units/"+eras[e]+"/"+clases[t]+"/";
      String[] acciones={"walk","idle","attack"};
      for(String accion:acciones){
        String real=accion.equals("attack")&&t==1?"idle_attack":accion;
        PImage[] sec=cargarSecuencia(ruta+real+"/");
        if(sec.length==0&&accion.equals("attack"))sec=cargarSecuencia(ruta+"walk_attack/");
        if(sec.length>0)animaciones.put(e+":"+t+":"+accion,sec);
      }
    }
  }
 
  for(int e=0;e<3;e++)for(int t=0;t<3;t++){
    String key=e+":"+t+":";
    if(!animaciones.containsKey(key+"idle")){
      PImage[] alternativa=animaciones.get(key+"walk");
      if(alternativa==null||alternativa.length==0)alternativa=animaciones.get(key+"attack");
      if(alternativa!=null&&alternativa.length>0)
        animaciones.put(key+"idle",new PImage[]{alternativa[0]});
    }
  }
 
  for(int e=0;e<3;e++)for(int t=0;t<3;t++)normalizarAnimaciones(e,t);
  println("[GRAFICOS] Sprites originales: "+animaciones.size()+" animaciones cargadas");
}
PImage loadOriginal(String ruta){
  File f=new File(dataPath("original/"+ruta));
  if(!f.isFile())return null;
  try{return loadImage(f.getAbsolutePath());}catch(Exception e){return null;}
}
File[] archivosPng(String carpeta){
  File f=new File(dataPath("original/"+carpeta));
  File[] a=f.listFiles(new FilenameFilter(){public boolean accept(File dir,String n){return n.toLowerCase().endsWith(".png");}});
  if(a==null)return new File[0];
  Arrays.sort(a,new java.util.Comparator<File>(){public int compare(File x,File y){return x.getName().compareTo(y.getName());}});
  return a;
}
PImage primerPng(String carpeta,String nombre){
  for(File f:archivosPng(carpeta))if(f.getName().contains(nombre)&&!f.getName().contains("projectile")){
    try{return loadImage(f.getAbsolutePath());}catch(Exception e){}
  }
  return null;
}
PImage[] cargarSecuencia(String carpeta){
  File[] todos=archivosPng(carpeta);
  ArrayList<PImage> sal=new ArrayList<PImage>();
  int cantidad=Math.min(10,todos.length);
  for(int i=0;i<cantidad;i++){
    int idx=(int)Math.floor((i+0.5f)*todos.length/cantidad);
    idx=Math.min(todos.length-1,idx);
    PImage a=loadImage(todos[idx].getAbsolutePath());
    if(a!=null)sal.add(a);
  }
  return sal.toArray(new PImage[sal.size()]);
}
void normalizarAnimaciones(int era,int tipo){
  String[] acciones={"walk","idle","attack"};
  String pref=era+":"+tipo+":";

  ArrayList<Integer> alturas=new ArrayList<Integer>();
  ArrayList<Integer> anchos=new ArrayList<Integer>();
  for(String a:new String[]{"walk","idle"}){
    PImage[] frames=animaciones.get(pref+a);
    if(frames==null)continue;
    for(PImage img:frames){int[] r=limitesAlfa(img);if(r[2]>2&&r[3]>2){alturas.add(r[3]);anchos.add(r[2]);}}
  }
  if(alturas.isEmpty())return;
  java.util.Collections.sort(alturas);java.util.Collections.sort(anchos);
  float altoObjetivo=alturas.get(alturas.size()/2);
  float anchoCuerpo=anchos.get(anchos.size()/2);
  // Normalizar todas las poses a la misma altura visual real.
  // No se cambia el tamano fotograma a fotograma en draw().
  int anchoMarco=Math.max(16,(int)(anchoCuerpo*1.65f)+10);
  int altoMarco=Math.max(16,(int)(altoObjetivo*1.12f)+8);
  PImage[][] originales=new PImage[3][];
  for(int i=0;i<3;i++)originales[i]=animaciones.get(pref+acciones[i]);
  for(int i=0;i<3;i++){
    PImage[] frames=originales[i];if(frames==null)continue;
    for(PImage img:frames){
      int[] r=limitesAlfa(img);
      if(r[2]<2||r[3]<2)continue;
      float factor=altoObjetivo/r[3];
      int w=(int)Math.ceil(r[2]*factor);
      anchoMarco=Math.max(anchoMarco,w+12);
    }
  }
 
  for(int i=0;i<3;i++){
    PImage[] frames=originales[i];if(frames==null)continue;
    PImage[] normalizados=new PImage[frames.length];
    for(int f=0;f<frames.length;f++){
      PImage img=frames[f];int[] r=limitesAlfa(img);
      PGraphics marco=createGraphics(anchoMarco,altoMarco);
      marco.beginDraw();marco.clear();
      if(r[2]>2&&r[3]>2){
        float factor=altoObjetivo/r[3];
        float w=r[2]*factor;
        marco.image(img,anchoMarco*.5f-w*.5f,altoMarco-4-altoObjetivo,w,altoObjetivo,
                    r[0],r[1],r[0]+r[2],r[1]+r[3]);
      }
      marco.endDraw();normalizados[f]=marco;
    }
    animaciones.put(pref+acciones[i],normalizados);
  }
  
  escalaVisual[era][tipo]=constrain(anchoMarco/Math.max(1,anchoCuerpo),1.0f,3.0f);
}
int[] limitesAlfa(PImage img){
  img.loadPixels();int x0=img.width,y0=img.height,x1=-1,y1=-1;
  for(int y=0;y<img.height;y++)for(int x=0;x<img.width;x++){
    if(((img.pixels[y*img.width+x]>>>24)&255)<=12)continue;
    x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);
  }
  if(x1<x0||y1<y0)return new int[]{0,0,1,1};
  return new int[]{x0,y0,x1-x0+1,y1-y0+1};
}
PImage recorteAlfa(PImage img){
  img.loadPixels();int x0=img.width,y0=img.height,x1=-1,y1=-1;
  for(int y=0;y<img.height;y++)for(int x=0;x<img.width;x++){
    if(((img.pixels[y*img.width+x]>>>24)&255)<=12)continue;
    x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);
  }
  if(x1<x0||y1<y0)return img;
  return img.get(x0,y0,x1-x0+1,y1-y0+1);
}

public void stop(){
  conexionActiva=false;
  try{if(servidorUDP!=null)servidorUDP.close();}catch(Exception e){}
  try{if(c!=null)c.stop();}catch(Exception e){}
  try{if(s!=null)s.stop();}catch(Exception e){}
  super.stop();
}
