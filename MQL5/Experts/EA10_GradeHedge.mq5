//+------------------------------------------------------------------+
//| EA 10 - Grade Hedge v2.00                                         |
//|                                                                  |
//| Reconstrucao a partir de um video de demonstracao (XAUUSD, H1).  |
//| O audio nao foi transcrito e o codigo original nao e conhecido.  |
//| NAO e o robo do video. A v2.00 corrige a logica com base na      |
//| lista de posicoes que aparece no video:                          |
//|                                                                  |
//|  1) Inicio do ciclo: sem posicoes -> abre COMPRA e VENDA (Ambos) |
//|     com o lote base, ao mesmo tempo.                             |
//|  2) Grade: o preco anda "Distancia grid" pontos contra a ultima  |
//|     ordem de um lado -> nova ordem desse lado com lote =         |
//|     (volume aberto desse lado) x Fator.                          |
//|       Fator 1: 0,01 -> 0,01 -> 0,02 -> 0,04 ...  (visto no video)|
//|       Fator 2: 0,01 -> 0,02 -> 0,06 -> 0,18 ...  (visto no video)|
//|  3) Saida: LUCRO TOTAL de todas as posicoes do EA >= "Limite de  |
//|     ganho trades" -> fecha TUDO e reabre o ciclo. Uma compra com |
//|     +$42 ficou aberta com alvo de $5 porque as vendas perdiam.   |
//|     "Limite de perda trades" fecha tudo pelo prejuizo total.     |
//|  4) Distancia grid = 0: nova ordem no lado perdedor a cada vela  |
//|     nova do grafico (inferido: no video a grade continuou        |
//|     abrindo ordens com distancia 0).                             |
//|                                                                  |
//| Conta NETTING (B3): so existe uma posicao por ativo, entao opera |
//| um lado so (Compra ou Venda); a grade soma contratos a posicao.  |
//|                                                                  |
//| RISCO: com a regra de lote do video, o volume DOBRA a cada nivel |
//| mesmo com fator 1. As protecoes do grupo 06 nao existem no video |
//| e vem LIGADAS por padrao.                                        |
//+------------------------------------------------------------------+
#property version   "2.00"
#property description "EA10: grade com fechamento pelo lucro total. Reconstrucao a partir de video; nao e o robo original."
#include <Trade/Trade.mqh>

enum ENUM_TIPO_TRADES
{
   TRADES_COMPRA = 0,   // Somente compras
   TRADES_VENDA  = 1,   // Somente vendas
   TRADES_AMBOS  = 2    // Compras e vendas
};

enum ENUM_MODO_SAIDA
{
   SAIDA_TOTAL = 0,     // Lucro TOTAL fecha tudo (como no video)
   SAIDA_CESTA = 1      // Cada lado fecha pelo proprio lucro
};

enum ENUM_MODO_LOTE
{
   LOTE_SOMA   = 0,     // Volume aberto do lado x fator (como no video)
   LOTE_ULTIMO = 1      // Ultimo lote x fator
};

input group "01 - PARAMETROS BASICOS"
input long NumeroMagico = 123;                 // Numero magico
input bool PermitirNoTestador = true;          // Operar no testador
input bool PermitirEmDemo = false;             // Operar em conta demo
input bool PermitirEmContaReal = false;        // Operar em conta real (bloqueado por padrao)
input bool MostrarDiagnosticos = true;         // Mensagens no Diario

input group "02 - LIMITES DIARIOS ($) | 0 desligado"
input double LimiteGanhoDiario = 0.0;          // Fecha tudo e para no dia ao ganhar $X (fechado + aberto)
input double LimitePerdaDiario = 0.0;          // Fecha tudo e para no dia ao perder $X (fechado + aberto)

input group "03 - LIMITES TRADES ($) | 0 desligado"
input double LimiteGanhoTrades = 5.0;          // Alvo em $ (total ou por lado, conforme o modo)
input double LimitePerdaTrades = 0.0;          // Stop em $ (total ou por lado, conforme o modo)
input ENUM_MODO_SAIDA ModoSaida = SAIDA_TOTAL; // Como o alvo/stop e medido

input group "04 - HORARIOS (HH:MM, servidor) | 0 desligado"
input string InicioEnvioOrdens = "00:01";      // Abre novos ciclos a partir deste horario
input string TerminoEnvioOrdens = "23:59";     // Nao abre novos ciclos depois deste horario
input string HorarioEncerrarTudo = "0";        // Fecha todas as posicoes neste horario

input group "05 - PARAMETROS OPERACIONAIS"
input ENUM_TIPO_TRADES TipoTrades = TRADES_AMBOS; // Tipo dos trades
input double Lote = 0.01;                      // Lote inicial
input int DistanciaGradePontos = 2000;         // Distancia grid em pontos (0 = uma ordem por vela nova)
input double FatorMultiplicacao = 1.0;         // Fator de multiplicacao
input ENUM_MODO_LOTE ModoLote = LOTE_SOMA;     // Regra do lote da grade

input group "06 - PROTECOES (nao existem no video)"
input int MaximoOrdensPorLado = 7;             // Limite de ordens de cada lado; 0 = sem limite (perigoso)
input double LoteMaximo = 0.64;                // Lote maximo de uma ordem; 0 = sem limite
input double StopPatrimonioPct = 30.0;         // Fecha tudo e desliga se patrimonio cair X% do pico; 0 desliga
input int SpreadMaximoPontos = 0;              // Nao abre ordens com spread acima disso; 0 desliga
input int DesvioMaximoPontos = 50;             // Desvio maximo na execucao

input group "07 - VISUAL"
input bool ExibirPainel = true;                // Painel de resultados
input bool RotulosPorPosicao = true;           // Linha e saldo de cada posicao no grafico
input int PainelX = 10;                        // Posicao horizontal do painel
input int PainelY = 20;                        // Posicao vertical do painel

input group "08 - OTIMIZACAO (OnTester)"
input int MinimoOperacoesOtimizacao = 30;      // Abaixo disso o criterio personalizado retorna 0

struct Lado
{
   int      qtd;
   double   volume;
   double   lucro;
   double   somaPrecoVol;
   double   precoUltima;
   double   loteUltimo;
};

CTrade negociador;
string prefixo;
bool visual=false;
string estado="Iniciando";
int minInicio=-1, minTermino=-1, minEncerrar=-1;
bool contaNetting=false;
ENUM_TIPO_TRADES tipoAtual;      // pode ser trocado pelo botao do painel (fora do testador)

bool historicoSujo=true;
datetime diaHistorico=0;
double fechadoDia=0.0, fechadoMes=0.0;

double picoTotal=0.0, picoDia=0.0, picoMes=0.0;
double ddTotal=0.0, ddDia=0.0, ddMes=0.0;
datetime diaDD=0, mesDD=0;

datetime diaBloqueado=0;
bool desligadoPorPatrimonio=false;
datetime ultimoPainel=0;
datetime ultimaVelaGradeC=0, ultimaVelaGradeV=0;

//+------------------------------------------------------------------+
bool AmbientePermitido()
{
   if(MQLInfoInteger(MQL_TESTER)) return PermitirNoTestador;
   if((ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL) return PermitirEmContaReal;
   return PermitirEmDemo;
}

int ConverterHorario(string t)
{
   StringTrimLeft(t); StringTrimRight(t);
   if(t=="" || t=="0") return -1;
   string p[];
   if(StringSplit(t,StringGetCharacter(":",0),p)!=2) return -2;
   int h=(int)StringToInteger(p[0]), m=(int)StringToInteger(p[1]);
   if(h<0 || h>23 || m<0 || m>59) return -2;
   return h*60+m;
}

int MinutoAtual() { MqlDateTime d; TimeToStruct(TimeCurrent(),d); return d.hour*60+d.min; }
datetime InicioDia(const datetime t) { MqlDateTime d; TimeToStruct(t,d); d.hour=0; d.min=0; d.sec=0; return StructToTime(d); }
datetime InicioMes(const datetime t) { MqlDateTime d; TimeToStruct(t,d); d.day=1; d.hour=0; d.min=0; d.sec=0; return StructToTime(d); }

bool DentroDoHorarioDeEnvio()
{
   if(minInicio<0 && minTermino<0) return true;
   int agora=MinutoAtual();
   int ini=(minInicio<0?0:minInicio), fim=(minTermino<0?24*60:minTermino);
   if(ini<=fim) return agora>=ini && agora<=fim;
   return agora>=ini || agora<=fim;
}

//+------------------------------------------------------------------+
bool PosicaoDoEA()
{
   return PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==NumeroMagico;
}

void LerLado(const ENUM_POSITION_TYPE tipo, Lado &l)
{
   l.qtd=0; l.volume=0; l.lucro=0; l.somaPrecoVol=0; l.precoUltima=0; l.loteUltimo=0;
   long ultimoTempo=-1, idPosicao=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0 || !PositionSelectByTicket(tk) || !PosicaoDoEA()) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)!=tipo) continue;
      double vol=PositionGetDouble(POSITION_VOLUME), preco=PositionGetDouble(POSITION_PRICE_OPEN);
      l.qtd++; l.volume+=vol; l.somaPrecoVol+=preco*vol;
      l.lucro+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      long t=PositionGetInteger(POSITION_TIME_MSC);
      if(t>ultimoTempo) { ultimoTempo=t; l.precoUltima=preco; l.loteUltimo=vol; }
      if(contaNetting) idPosicao=PositionGetInteger(POSITION_IDENTIFIER);
   }
   // NETTING: a posicao unica so guarda o preco medio; niveis, ultimo preco e
   // ultimo lote vem dos negocios de entrada dessa posicao.
   if(contaNetting && l.qtd>0 && idPosicao>0 && HistorySelectByPosition(idPosicao))
   {
      int entradas=0; long ultimo=-1;
      for(int i=0;i<HistoryDealsTotal();i++)
      {
         ulong d=HistoryDealGetTicket(i);
         if(d==0) continue;
         long e=HistoryDealGetInteger(d,DEAL_ENTRY);
         if(e!=DEAL_ENTRY_IN && e!=DEAL_ENTRY_INOUT) continue;
         entradas++;
         long t=HistoryDealGetInteger(d,DEAL_TIME_MSC);
         if(t>ultimo) { ultimo=t; l.precoUltima=HistoryDealGetDouble(d,DEAL_PRICE); l.loteUltimo=HistoryDealGetDouble(d,DEAL_VOLUME); }
      }
      if(entradas>0) l.qtd=entradas;
   }
}

void FecharLado(const ENUM_POSITION_TYPE tipo)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0 || !PositionSelectByTicket(tk) || !PosicaoDoEA()) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)!=tipo) continue;
      if(!negociador.PositionClose(tk))
         PrintFormat("Falha ao fechar %I64u: %s",tk,negociador.ResultRetcodeDescription());
   }
   historicoSujo=true;
}

void FecharTudo(const string motivo)
{
   FecharLado(POSITION_TYPE_BUY);
   FecharLado(POSITION_TYPE_SELL);
   if(MostrarDiagnosticos) Print("Todas as posicoes fechadas: ",motivo);
}

//+------------------------------------------------------------------+
double NormalizarLote(double desejado)
{
   double minimo=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), maximo=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double passo=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(minimo<=0 || passo<=0) return 0.0;
   if(LoteMaximo>0.0) desejado=MathMin(desejado,LoteMaximo);
   desejado=MathMin(desejado,maximo);
   double v=MathFloor(desejado/passo+1e-9)*passo;
   if(v<minimo) v=minimo;
   return NormalizeDouble(v,8);
}

bool AbrirOrdem(const ENUM_POSITION_TYPE lado, const double loteDesejado, const string comentario)
{
   if(SpreadMaximoPontos>0 && SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>SpreadMaximoPontos) { estado="Spread alto"; return false; }
   double vol=NormalizarLote(loteDesejado);
   if(vol<=0) { estado="Lote invalido"; return false; }
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0 || tick.ask<=0) return false;
   ENUM_ORDER_TYPE tipo=(lado==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   double margem=0.0;
   if(!OrderCalcMargin(tipo,_Symbol,vol,lado==POSITION_TYPE_BUY?tick.ask:tick.bid,margem) ||
      margem>AccountInfoDouble(ACCOUNT_MARGIN_FREE)) { estado="Margem insuficiente"; return false; }
   bool ok=(lado==POSITION_TYPE_BUY?negociador.Buy(vol,_Symbol,0,0,0,comentario):negociador.Sell(vol,_Symbol,0,0,0,comentario));
   uint rc=negociador.ResultRetcode();
   if(!ok || (rc!=TRADE_RETCODE_DONE && rc!=TRADE_RETCODE_DONE_PARTIAL))
   {
      estado="Ordem recusada: "+negociador.ResultRetcodeDescription();
      PrintFormat("ORDEM RECUSADA (%s %.2f): %s",lado==POSITION_TYPE_BUY?"compra":"venda",vol,negociador.ResultRetcodeDescription());
      return false;
   }
   historicoSujo=true;
   return true;
}

// Lote da proxima ordem da grade de um lado.
double LoteDaGrade(const Lado &l)
{
   if(ModoLote==LOTE_SOMA) return l.volume*FatorMultiplicacao;
   return l.loteUltimo*FatorMultiplicacao;
}

//+------------------------------------------------------------------+
void AtualizarHistorico()
{
   datetime hoje=InicioDia(TimeCurrent());
   if(!historicoSujo && hoje==diaHistorico) return;
   fechadoDia=0.0; fechadoMes=0.0;
   if(HistorySelect(InicioMes(TimeCurrent()),TimeCurrent()+86400))
   {
      for(int i=0;i<HistoryDealsTotal();i++)
      {
         ulong d=HistoryDealGetTicket(i);
         if(d==0 || HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol || HistoryDealGetInteger(d,DEAL_MAGIC)!=NumeroMagico) continue;
         long tp=HistoryDealGetInteger(d,DEAL_TYPE);
         if(tp!=DEAL_TYPE_BUY && tp!=DEAL_TYPE_SELL) continue;
         double r=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_COMMISSION)
                 +HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_FEE);
         fechadoMes+=r;
         if((datetime)HistoryDealGetInteger(d,DEAL_TIME)>=hoje) fechadoDia+=r;
      }
   }
   diaHistorico=hoje; historicoSujo=false;
}

void AtualizarDrawdown()
{
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   datetime hoje=InicioDia(TimeCurrent()), mes=InicioMes(TimeCurrent());
   if(hoje!=diaDD) { diaDD=hoje; picoDia=eq; ddDia=0; }
   if(mes!=mesDD) { mesDD=mes; picoMes=eq; ddMes=0; }
   picoTotal=MathMax(picoTotal,eq); picoDia=MathMax(picoDia,eq); picoMes=MathMax(picoMes,eq);
   ddTotal=MathMax(ddTotal,picoTotal-eq); ddDia=MathMax(ddDia,picoDia-eq); ddMes=MathMax(ddMes,picoMes-eq);
}

//+------------------------------------------------------------------+
// VISUAL: painel proprio + linha e saldo de cada posicao.
void Rotulo(const string nome, const int x, const int y, const string texto, const color cor, const int tamanho=9)
{
   if(ObjectFind(0,nome)<0)
   {
      ObjectCreate(0,nome,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,nome,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetString(0,nome,OBJPROP_FONT,"Consolas");
      ObjectSetInteger(0,nome,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nome,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,nome,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,nome,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,nome,OBJPROP_FONTSIZE,tamanho);
   ObjectSetInteger(0,nome,OBJPROP_COLOR,cor);
   ObjectSetString(0,nome,OBJPROP_TEXT,texto);
}

void Caixa(const string nome, const int x, const int y, const int w, const int h, const color fundo, const color borda)
{
   if(ObjectFind(0,nome)<0)
   {
      ObjectCreate(0,nome,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,nome,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,nome,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,nome,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nome,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,nome,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,nome,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,nome,OBJPROP_XSIZE,w); ObjectSetInteger(0,nome,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,nome,OBJPROP_BGCOLOR,fundo); ObjectSetInteger(0,nome,OBJPROP_COLOR,borda);
}

string TextoTipo(const ENUM_TIPO_TRADES t) { return t==TRADES_AMBOS?"Compra + Venda":t==TRADES_COMPRA?"Compra":"Venda"; }
color CorValor(const double v) { return v>=0?C'90,200,120':C'240,90,90'; }

void DesenharPainel(const Lado &c, const Lado &v)
{
   if(!visual || !ExibirPainel) return;
   int x=PainelX, y=PainelY, w=260;
   color fundo=C'22,26,40', borda=C'90,80,150', cinza=C'170,175,195', valor=C'235,215,150';
   Caixa(prefixo+"BG",x,y,w,330,fundo,borda);
   Rotulo(prefixo+"T0",x+10,y+8,"GRADE HEDGE EA10",C'200,170,255',11);
   Rotulo(prefixo+"T1",x+10,y+32,"Hora servidor: "+TimeToString(TimeCurrent(),TIME_SECONDS),cinza);
   Rotulo(prefixo+"T2",x+10,y+50,"Ativo: "+_Symbol,cinza);

   // Botao do tipo de trade (troca ao vivo; no testador fica so informativo).
   string bt=prefixo+"BTIPO";
   if(ObjectFind(0,bt)<0)
   {
      ObjectCreate(0,bt,OBJ_BUTTON,0,0,0);
      ObjectSetInteger(0,bt,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,bt,OBJPROP_FONTSIZE,8);
      ObjectSetInteger(0,bt,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,bt,OBJPROP_XDISTANCE,x+140); ObjectSetInteger(0,bt,OBJPROP_YDISTANCE,y+46);
   ObjectSetInteger(0,bt,OBJPROP_XSIZE,110); ObjectSetInteger(0,bt,OBJPROP_YSIZE,20);
   ObjectSetInteger(0,bt,OBJPROP_BGCOLOR,C'45,50,75'); ObjectSetInteger(0,bt,OBJPROP_COLOR,clrWhite);
   ObjectSetString(0,bt,OBJPROP_TEXT,TextoTipo(tipoAtual));
   ObjectSetInteger(0,bt,OBJPROP_STATE,false);

   double atual=c.lucro+v.lucro;
   string nomes[3]={"Resultado atual","Resultado do dia","Resultado do mes"};
   double vals[3];
   vals[0]=atual; vals[1]=fechadoDia+atual; vals[2]=fechadoMes+atual;
   for(int i=0;i<3;i++)
   {
      int yy=y+76+i*40;
      Caixa(prefixo+"C"+IntegerToString(i),x+8,yy,w-16,34,C'30,34,52',C'60,60,95');
      Rotulo(prefixo+"CN"+IntegerToString(i),x+16,yy+3,nomes[i],cinza,8);
      Rotulo(prefixo+"CV"+IntegerToString(i),x+120,yy+15,DoubleToString(vals[i],2)+" "+AccountInfoString(ACCOUNT_CURRENCY),
             i==0?valor:CorValor(vals[i]),10);
   }
   Rotulo(prefixo+"D0",x+10,y+200,"Drawdown do dia:   "+DoubleToString(ddDia,2),C'120,190,230',8);
   Rotulo(prefixo+"D1",x+10,y+216,"Drawdown do mes:   "+DoubleToString(ddMes,2),C'120,190,230',8);
   Rotulo(prefixo+"D2",x+10,y+232,"Drawdown total:    "+DoubleToString(ddTotal,2),C'120,190,230',8);

   // Preco de equilibrio do conjunto (onde o lucro total e zero, sem custos).
   double liquido=c.volume-v.volume;
   string precoPos="-";
   if(MathAbs(liquido)>1e-8) precoPos=DoubleToString((c.somaPrecoVol-v.somaPrecoVol)/liquido,_Digits);
   else if(c.volume>0 && v.volume==0) precoPos=DoubleToString(c.somaPrecoVol/c.volume,_Digits);
   Caixa(prefixo+"PP",x+8,y+254,118,36,C'30,34,52',C'60,60,95');
   Caixa(prefixo+"CT",x+134,y+254,118,36,C'30,34,52',C'60,60,95');
   Rotulo(prefixo+"PPN",x+14,y+256,"Preco equilibrio",cinza,8);
   Rotulo(prefixo+"PPV",x+14,y+271,precoPos,C'120,190,230',9);
   Rotulo(prefixo+"CTN",x+140,y+256,"Contratos C/V",cinza,8);
   Rotulo(prefixo+"CTV",x+140,y+271,DoubleToString(c.volume,2)+" / "+DoubleToString(v.volume,2),valor,9);
   Rotulo(prefixo+"ST",x+10,y+300,"Estado: "+estado,desligadoPorPatrimonio?clrTomato:clrKhaki,8);
   Rotulo(prefixo+"AV",x+10,y+314,"Reconstrucao propria - nao e o robo do video",C'110,110,130',7);
}

// Uma linha pontilhada e um texto "Saldo compra/venda" em cada posicao aberta.
void DesenharPosicoes()
{
   if(!visual || !RotulosPorPosicao) return;
   // Marca as existentes para depois apagar as de posicoes ja fechadas.
   string vivos[]; int nv=0;
   datetime tDireita=iTime(_Symbol,PERIOD_CURRENT,0)+PeriodSeconds(PERIOD_CURRENT)*3;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0 || !PositionSelectByTicket(tk) || !PosicaoDoEA()) continue;
      bool compra=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
      double preco=PositionGetDouble(POSITION_PRICE_OPEN);
      double lucro=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      string l=prefixo+"PL"+IntegerToString((long)tk), t=prefixo+"PT"+IntegerToString((long)tk);
      if(ObjectFind(0,l)<0)
      {
         ObjectCreate(0,l,OBJ_HLINE,0,0,preco);
         ObjectSetInteger(0,l,OBJPROP_STYLE,STYLE_DOT);
         ObjectSetInteger(0,l,OBJPROP_COLOR,compra?C'70,170,110':C'200,80,80');
         ObjectSetInteger(0,l,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,l,OBJPROP_HIDDEN,true);
         ObjectCreate(0,t,OBJ_TEXT,0,tDireita,preco);
         ObjectSetInteger(0,t,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
         ObjectSetInteger(0,t,OBJPROP_FONTSIZE,8);
         ObjectSetInteger(0,t,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,t,OBJPROP_HIDDEN,true);
      }
      ObjectMove(0,t,0,tDireita,preco);
      ObjectSetString(0,t,OBJPROP_TEXT,StringFormat("Saldo %s %.2f: %.2f",compra?"compra":"venda",PositionGetDouble(POSITION_VOLUME),lucro));
      ObjectSetInteger(0,t,OBJPROP_COLOR,CorValor(lucro));
      ArrayResize(vivos,nv+2); vivos[nv++]=l; vivos[nv++]=t;
   }
   for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--)
   {
      string nome=ObjectName(0,i,0,-1);
      if(StringFind(nome,prefixo+"PL")!=0 && StringFind(nome,prefixo+"PT")!=0) continue;
      bool achou=false;
      for(int k=0;k<nv && !achou;k++) achou=(vivos[k]==nome);
      if(!achou) ObjectDelete(0,nome);
   }
}

void AtualizarVisual()
{
   if(!visual) return;
   Lado c, v;
   LerLado(POSITION_TYPE_BUY,c);
   LerLado(POSITION_TYPE_SELL,v);
   DesenharPainel(c,v);
   DesenharPosicoes();
   ChartRedraw(0);
}

void LimparObjetos()
{
   for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--)
   {
      string nome=ObjectName(0,i,0,-1);
      if(StringFind(nome,prefixo)==0) ObjectDelete(0,nome);
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   minInicio=ConverterHorario(InicioEnvioOrdens);
   minTermino=ConverterHorario(TerminoEnvioOrdens);
   minEncerrar=ConverterHorario(HorarioEncerrarTudo);
   if(minInicio==-2 || minTermino==-2 || minEncerrar==-2) { Print("Horario invalido: use HH:MM ou 0."); return INIT_PARAMETERS_INCORRECT; }
   if(NumeroMagico<=0 || Lote<=0 || LimiteGanhoTrades<0 || LimitePerdaTrades<0 || LimiteGanhoDiario<0 || LimitePerdaDiario<0 ||
      DistanciaGradePontos<0 || FatorMultiplicacao<=0 || FatorMultiplicacao>10 || MaximoOrdensPorLado<0 || LoteMaximo<0 ||
      StopPatrimonioPct<0 || StopPatrimonioPct>=100 || SpreadMaximoPontos<0 || DesvioMaximoPontos<0)
   { Print("Parametros invalidos."); return INIT_PARAMETERS_INCORRECT; }
   if(LimiteGanhoTrades==0 && LimitePerdaTrades==0)
      Print("ATENCAO: sem limite de ganho/perda dos trades as posicoes so fecham pelos limites diarios, horario ou protecoes.");

   contaNetting=((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   if(contaNetting && TipoTrades==TRADES_AMBOS)
   { Print("Conta NETTING (ex.: B3): escolha Tipo dos trades = Compra ou Venda. 'Ambos' exige conta HEDGING."); return INIT_PARAMETERS_INCORRECT; }
   tipoAtual=TipoTrades;

   negociador.SetExpertMagicNumber((ulong)NumeroMagico);
   negociador.SetDeviationInPoints((ulong)DesvioMaximoPontos);
   negociador.SetTypeFillingBySymbol(_Symbol);
   negociador.LogLevel(LOG_LEVEL_ERRORS);

   prefixo="EA10_"+IntegerToString(NumeroMagico)+"_";
   visual=(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE));
   picoTotal=AccountInfoDouble(ACCOUNT_EQUITY);
   if(visual)
   {
      ChartSetInteger(0,CHART_FOREGROUND,false);
      EventSetTimer(1);
      estado=(AmbientePermitido()?"Aguardando tick":"Bloqueado neste ambiente (veja grupo 01)");
      AtualizarHistorico();
      AtualizarVisual();
   }
   PrintFormat("EA10 v2.00 (%s): %s, tipo=%s, lote=%.2f, grid=%d pts, fator=%.2f, alvo=%.2f (%s), lote da grade=%s",
               contaNetting?"NETTING":"HEDGING",_Symbol,TextoTipo(TipoTrades),Lote,DistanciaGradePontos,FatorMultiplicacao,
               LimiteGanhoTrades,ModoSaida==SAIDA_TOTAL?"total":"por lado",ModoLote==LOTE_SOMA?"soma x fator":"ultimo x fator");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int motivo)
{
   if(visual) { EventKillTimer(); LimparObjetos(); ChartRedraw(0); }
}

void OnTimer() { AtualizarHistorico(); AtualizarDrawdown(); AtualizarVisual(); }

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   // Botao do painel: alterna Ambos -> Compra -> Venda (Ambos so em conta HEDGING).
   if(id==CHARTEVENT_OBJECT_CLICK && sparam==prefixo+"BTIPO")
   {
      if(tipoAtual==TRADES_AMBOS) tipoAtual=TRADES_COMPRA;
      else if(tipoAtual==TRADES_COMPRA) tipoAtual=TRADES_VENDA;
      else tipoAtual=(contaNetting?TRADES_COMPRA:TRADES_AMBOS);
      Print("Tipo dos trades alterado para: ",TextoTipo(tipoAtual));
      AtualizarVisual();
   }
}

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res)
{
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD) historicoSujo=true;
}

double OnTester()
{
   double ops=TesterStatistics(STAT_TRADES), lucro=TesterStatistics(STAT_PROFIT);
   double dd=TesterStatistics(STAT_EQUITY_DD), pf=TesterStatistics(STAT_PROFIT_FACTOR);
   if(ops<MinimoOperacoesOtimizacao || lucro<=0) return 0.0;
   if(dd<=0) dd=1.0;
   return (lucro/dd)*MathMin(pf,5.0);
}

//+------------------------------------------------------------------+
// Grade de um lado: nova ordem quando o preco anda contra a ultima.
void Grade(const ENUM_POSITION_TYPE lado, const Lado &l, const MqlTick &tick, datetime &ultimaVela)
{
   if(l.qtd==0) return;
   bool compra=(lado==POSITION_TYPE_BUY);
   bool contra;
   if(DistanciaGradePontos>0)
      contra=(compra ? tick.ask<=l.precoUltima-DistanciaGradePontos*_Point : tick.bid>=l.precoUltima+DistanciaGradePontos*_Point);
   else
   {
      // Distancia 0: no maximo uma ordem por vela nova, se o preco estiver contra a ultima.
      datetime vela=iTime(_Symbol,PERIOD_CURRENT,0);
      contra=(vela!=ultimaVela && (compra ? tick.ask<l.precoUltima : tick.bid>l.precoUltima));
      if(contra) ultimaVela=vela;
   }
   if(!contra) return;
   if(MaximoOrdensPorLado>0 && l.qtd>=MaximoOrdensPorLado) { estado=StringFormat("Grade de %s no limite (%d)",compra?"compras":"vendas",l.qtd); return; }
   double lote=LoteDaGrade(l);
   if(AbrirOrdem(lado,lote,StringFormat("EA10 grade %s%d",compra?"C":"V",l.qtd+1)))
   {
      estado=StringFormat("Grade %s #%d",compra?"compra":"venda",l.qtd+1);
      if(MostrarDiagnosticos) PrintFormat("%s: lote %.2f (volume aberto %.2f x fator %.2f)",estado,NormalizarLote(lote),l.volume,FatorMultiplicacao);
   }
}

void OnTick()
{
   AtualizarHistorico();
   AtualizarDrawdown();
   if(visual && TimeCurrent()!=ultimoPainel) { ultimoPainel=TimeCurrent(); AtualizarVisual(); }
   if(!AmbientePermitido()) { estado="Bloqueado neste ambiente (veja grupo 01)"; return; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED)) { estado="Algotrading desligado"; return; }

   Lado c, v;
   LerLado(POSITION_TYPE_BUY,c);
   LerLado(POSITION_TYPE_SELL,v);
   int total=c.qtd+v.qtd;
   double lucroAberto=c.lucro+v.lucro;

   // 1) Stop de patrimonio (protecao propria): fecha tudo e desliga.
   double eq=AccountInfoDouble(ACCOUNT_EQUITY);
   if(!desligadoPorPatrimonio && StopPatrimonioPct>0 && picoTotal>0 && eq<=picoTotal*(1.0-StopPatrimonioPct/100.0))
   {
      desligadoPorPatrimonio=true;
      PrintFormat("STOP DE PATRIMONIO: %.2f caiu %.1f%% do pico %.2f. Fechando tudo e desligando.",eq,100*(picoTotal-eq)/picoTotal,picoTotal);
   }
   if(desligadoPorPatrimonio) { estado="DESLIGADO: stop de patrimonio"; if(total>0) FecharTudo("stop de patrimonio"); return; }

   // 2) Horario de encerramento: fecha tudo e nao abre ate a meia-noite.
   if(minEncerrar>=0 && MinutoAtual()>=minEncerrar) { estado="Horario de encerramento"; if(total>0) FecharTudo("horario de encerramento"); return; }

   // 3) Limites diarios (fechado no dia + aberto).
   datetime hoje=InicioDia(TimeCurrent());
   double resultadoDia=fechadoDia+lucroAberto;
   if(diaBloqueado!=hoje && ((LimiteGanhoDiario>0 && resultadoDia>=LimiteGanhoDiario) || (LimitePerdaDiario>0 && resultadoDia<=-LimitePerdaDiario)))
   { diaBloqueado=hoje; PrintFormat("Limite diario atingido (%.2f). Parado ate amanha.",resultadoDia); }
   if(diaBloqueado==hoje) { estado="Limite diario atingido"; if(total>0) FecharTudo("limite diario"); return; }

   // 4) Alvo / stop dos trades.
   if(ModoSaida==SAIDA_TOTAL)
   {
      if(total>0 && LimiteGanhoTrades>0 && lucroAberto>=LimiteGanhoTrades) { FecharTudo(StringFormat("alvo total %.2f",lucroAberto)); estado="Alvo total atingido"; return; }
      if(total>0 && LimitePerdaTrades>0 && lucroAberto<=-LimitePerdaTrades) { FecharTudo(StringFormat("stop total %.2f",lucroAberto)); estado="Stop total atingido"; return; }
   }
   else
   {
      bool fechou=false;
      if(c.qtd>0 && ((LimiteGanhoTrades>0 && c.lucro>=LimiteGanhoTrades) || (LimitePerdaTrades>0 && c.lucro<=-LimitePerdaTrades)))
      { FecharLado(POSITION_TYPE_BUY); fechou=true; if(MostrarDiagnosticos) PrintFormat("Compras fechadas: %.2f",c.lucro); }
      if(v.qtd>0 && ((LimiteGanhoTrades>0 && v.lucro>=LimiteGanhoTrades) || (LimitePerdaTrades>0 && v.lucro<=-LimitePerdaTrades)))
      { FecharLado(POSITION_TYPE_SELL); fechou=true; if(MostrarDiagnosticos) PrintFormat("Vendas fechadas: %.2f",v.lucro); }
      if(fechou) return;
   }

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0 || tick.ask<=0) return;

   // 5) Grade dos lados abertos (continua fora da janela de envio).
   Grade(POSITION_TYPE_BUY,c,tick,ultimaVelaGradeC);
   Grade(POSITION_TYPE_SELL,v,tick,ultimaVelaGradeV);

   // 6) Novo ciclo, somente dentro da janela de envio.
   if(!DentroDoHorarioDeEnvio()) { if(total==0) estado="Fora do horario de envio"; return; }
   bool operaC=(tipoAtual!=TRADES_VENDA), operaV=(tipoAtual!=TRADES_COMPRA);
   if(ModoSaida==SAIDA_TOTAL)
   {
      // No video o ciclo so recomeca sem nenhuma posicao: abre os dois lados juntos.
      if(total>0) return;
      if(operaC && AbrirOrdem(POSITION_TYPE_BUY,Lote,"EA10 Compra")) estado="Novo ciclo";
      if(operaV && AbrirOrdem(POSITION_TYPE_SELL,Lote,"EA10 Venda")) estado="Novo ciclo";
   }
   else
   {
      if(operaC && c.qtd==0 && AbrirOrdem(POSITION_TYPE_BUY,Lote,"EA10 Compra")) estado="Nova cesta de compras";
      if(operaV && v.qtd==0 && AbrirOrdem(POSITION_TYPE_SELL,Lote,"EA10 Venda")) estado="Nova cesta de vendas";
   }
}
//+------------------------------------------------------------------+
