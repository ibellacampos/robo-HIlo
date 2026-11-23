//+------------------------------------------------------------------+
//| EA 14 - Preco Reativo com Grade (WIN, M1)                         |
//|                                                                  |
//| Reconstrucao a partir de um video ("setup agressivo com preco    |
//| reativo - mini indice", WINJ25 M1, conta hedging). O audio nao   |
//| foi transcrito e o codigo original nao e conhecido: NAO e o robo |
//| do video. Pontos inferidos estao marcados com [INTERPRETADO].    |
//|                                                                  |
//| O que aparece no painel do video:                                |
//|  - Entrada com 10 contratos; depois 20 e 30 no MESMO lado com o  |
//|    preco medio mudando (ex.: venda 10 @127180 -> 20 @127215, ou  |
//|    seja +10 contratos ~70 pts contra).                           |
//|  - Ciclos fechados inteiros pelo resultado do preco medio        |
//|    (ex.: 30 contratos, +345 pts = R$ 750 em aberto).             |
//|  - Linhas tracejadas verdes (niveis da grade) e vermelhas        |
//|    (limite/stop) no grafico.                                     |
//|  - Eficiencia por dia/semana/mes/total e botao "Zerar".          |
//|                                                                  |
//| Logica deste EA:                                                 |
//|  1) Gatilho "preco reativo" [INTERPRETADO]: o preco andou pelo   |
//|     menos X pontos nas ultimas N velas e a ultima vela fechada   |
//|     reagiu na direcao contraria (corpo minimo). Entra na reacao. |
//|     Opcao: entrar a favor do movimento (continuacao).            |
//|  2) Grade: a cada X pontos contra o ULTIMO preco de entrada,     |
//|     adiciona o mesmo lote, ate o maximo de niveis.               |
//|  3) Saida: alvo em pontos sobre o preco medio; stop em pontos a  |
//|     partir do preco medio depois do ultimo nivel ou da 1a        |
//|     entrada (configuravel); zeragem e limites diarios.           |
//+------------------------------------------------------------------+
#property version   "1.00"
#property description "EA14: reacao de preco com grade de entradas e saida pelo preco medio. Reconstrucao a partir de video; nao e o robo original."
#include <Trade/Trade.mqh>

enum ENUM_MODO_SINAL { SINAL_REVERSAO=0, SINAL_CONTINUACAO=1 };
enum ENUM_BASE_STOP  { STOP_PRIMEIRA=0, STOP_PRECO_MEDIO=1 };

input group "01 - GERAL"
input long   NumeroMagico = 2025;               // Numero magico
input bool   PermitirNoTestador = true;         // Operar no testador
input bool   PermitirEmDemo = false;            // Operar em conta demo
input bool   PermitirEmContaReal = false;       // Operar em conta real (bloqueado por padrao)
input ENUM_TIMEFRAMES TempoGrafico = PERIOD_M1; // Tempo grafico do sinal
input bool   PermitirCompras = true;            // Operar compras
input bool   PermitirVendas = true;             // Operar vendas

input group "02 - SINAL: PRECO REATIVO"
input ENUM_MODO_SINAL ModoSinal = SINAL_REVERSAO; // Reversao (reacao) ou continuacao
input int    JanelaVelas = 10;                  // Velas para medir o movimento
input int    MovimentoMinimoPontos = 250;       // Movimento minimo na janela (pontos)
input double CorpoMinimoReacao = 0.5;           // Corpo da vela de reacao / amplitude (0-1)

input group "03 - LOTE E GRADE"
input double Contratos = 10;                    // Contratos por entrada
input int    EspacamentoGradePontos = 70;       // Nova entrada a cada X pontos contra a ultima
input int    NiveisMaximos = 3;                 // Entradas maximas por ciclo (1 = sem grade)

input group "04 - SAIDA (pontos)"
input int    AlvoPontos = 100;                  // Alvo sobre o preco medio
input int    StopPontos = 300;                  // Stop
input ENUM_BASE_STOP BaseStop = STOP_PRIMEIRA;  // Stop medido da 1a entrada ou do preco medio
input int    TrailingInicioPontos = 0;          // Trailing sobre o preco medio apos X pontos (0 desliga)
input int    TrailingDistanciaPontos = 60;      // Distancia do trailing

input group "05 - HORARIO E LIMITES"
input string HoraInicio = "09:05";              // Inicio das entradas (HH:MM)
input string HoraFim = "16:30";                 // Fim das entradas (HH:MM)
input string HoraZeragem = "17:45";             // Zeragem (HH:MM); 0 desliga
input int    CiclosMaximosDia = 0;              // Ciclos por dia (0 = sem limite)
input double PerdaMaximaDia = 600;              // Para no dia ao perder R$ X (0 desliga)
input double GanhoMaximoDia = 0;                // Para no dia ao ganhar R$ X (0 desliga)
input int    EsperaAposCicloVelas = 2;          // Velas de espera depois de um ciclo
input int    DesvioMaximoPontos = 20;           // Desvio maximo na execucao

input group "06 - VISUAL"
input bool   ExibirPainel = true;               // Painel
input bool   DesenharNiveis = true;             // Linhas de grade, alvo e stop
input int    PainelX = 10;                      // Posicao horizontal
input int    PainelY = 25;                      // Posicao vertical

struct Cesta { int lado; int n; double vol; double precoMedio; double lucro; double precoPrimeira; double precoUltima; };
struct Estat { int ciclos; int acertos; double lucro; };

CTrade negociador;
string prefixo, estado="Iniciando";
bool visual=false, contaNetting=false;
int minInicio=-1, minFim=-1, minZeragem=-1;
datetime ultimaBarra=0, fimUltimoCiclo=0;
bool historicoSujo=true;
Estat eDia, eSemana, eMes, eTotal;
int niveisCiclo=0; double precoUltimaEntrada=0, precoPrimeiraEntrada=0, melhorSL=0;

//+------------------------------------------------------------------+
int ConverterHorario(string t)
{
   StringTrimLeft(t); StringTrimRight(t);
   if(t=="" || t=="0") return -1;
   string p[]; if(StringSplit(t,StringGetCharacter(":",0),p)!=2) return -2;
   int h=(int)StringToInteger(p[0]), m=(int)StringToInteger(p[1]);
   if(h<0 || h>23 || m<0 || m>59) return -2;
   return h*60+m;
}
int MinutoAtual() { MqlDateTime d; TimeToStruct(TimeCurrent(),d); return d.hour*60+d.min; }
datetime InicioDia(const datetime t) { MqlDateTime d; TimeToStruct(t,d); d.hour=0; d.min=0; d.sec=0; return StructToTime(d); }
datetime InicioMes(const datetime t) { MqlDateTime d; TimeToStruct(t,d); d.day=1; d.hour=0; d.min=0; d.sec=0; return StructToTime(d); }
datetime InicioSemana(const datetime t) { MqlDateTime d; TimeToStruct(t,d); return InicioDia(t)-(datetime)(d.day_of_week*86400); }
bool AmbientePermitido()
{
   if(MQLInfoInteger(MQL_TESTER)) return PermitirNoTestador;
   if((ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL) return PermitirEmContaReal;
   return PermitirEmDemo;
}
double Ajustar(const double p) { double s=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); if(s<=0) s=_Point; return NormalizeDouble(MathRound(p/s)*s,_Digits); }
double Volume(double v) { double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP); if(st<=0) st=mn; return MathMax(mn,NormalizeDouble(MathFloor(v/st+1e-9)*st,8)); }

//+------------------------------------------------------------------+
bool MinhaPosicao() { return PositionGetString(POSITION_SYMBOL)==_Symbol && PositionGetInteger(POSITION_MAGIC)==NumeroMagico; }

void LerCesta(Cesta &c)
{
   c.lado=0; c.n=0; c.vol=0; c.precoMedio=0; c.lucro=0; c.precoPrimeira=0; c.precoUltima=0;
   double soma=0; long primeiro=LONG_MAX, ultimo=-1;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0 || !PositionSelectByTicket(tk) || !MinhaPosicao()) continue;
      double v=PositionGetDouble(POSITION_VOLUME), p=PositionGetDouble(POSITION_PRICE_OPEN);
      c.lado=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1);
      c.n++; c.vol+=v; soma+=v*p; c.lucro+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      long t=PositionGetInteger(POSITION_TIME_MSC);
      if(t<primeiro) { primeiro=t; c.precoPrimeira=p; }
      if(t>ultimo) { ultimo=t; c.precoUltima=p; }
   }
   if(c.vol>0) c.precoMedio=soma/c.vol;
}

void FecharTudo(const string motivo)
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk>0 && PositionSelectByTicket(tk) && MinhaPosicao())
         if(!negociador.PositionClose(tk)) PrintFormat("EA14: falha ao fechar %I64u: %s",tk,negociador.ResultRetcodeDescription());
   }
   historicoSujo=true;
   Print("EA14: ciclo encerrado (",motivo,")");
}

//+------------------------------------------------------------------+
// Estatisticas por ciclo (saidas no mesmo segundo = 1 ciclo).
void Somar(Estat &e, const double r) { e.ciclos++; if(r>0) e.acertos++; e.lucro+=r; }
void AtualizarHistorico()
{
   if(!historicoSujo) return;
   datetime hoje=InicioDia(TimeCurrent()), sem=InicioSemana(TimeCurrent()), mes=InicioMes(TimeCurrent());
   ZeroMemory(eDia); ZeroMemory(eSemana); ZeroMemory(eMes); ZeroMemory(eTotal);
   if(HistorySelect(0,TimeCurrent()+86400))
   {
      datetime tC=0; double rC=0;
      int total=HistoryDealsTotal();
      for(int i=0;i<=total;i++)
      {
         bool fim=(i==total); bool saida=false; datetime t=0; double r=0;
         if(!fim)
         {
            ulong d=HistoryDealGetTicket(i);
            if(d>0 && HistoryDealGetString(d,DEAL_SYMBOL)==_Symbol && HistoryDealGetInteger(d,DEAL_MAGIC)==NumeroMagico)
            {
               long tp=HistoryDealGetInteger(d,DEAL_TYPE);
               if(tp==DEAL_TYPE_BUY || tp==DEAL_TYPE_SELL)
               {
                  r=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_COMMISSION)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_FEE);
                  t=(datetime)HistoryDealGetInteger(d,DEAL_TIME);
                  saida=(HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_IN);
               }
            }
         }
         if((fim || (saida && MathAbs((long)(t-tC))>2)) && tC>0)
         {
            Somar(eTotal,rC); if(tC>=mes) Somar(eMes,rC); if(tC>=sem) Somar(eSemana,rC); if(tC>=hoje) Somar(eDia,rC);
            tC=0; rC=0;
         }
         if(saida) { tC=t; rC+=r; }
      }
   }
   historicoSujo=false;
}

//+------------------------------------------------------------------+
// 1 compra, -1 venda, 0 nada (avalia velas fechadas).
int Sinal()
{
   int n=MathMax(2,JanelaVelas);
   MqlRates r[];
   if(CopyRates(_Symbol,TempoGrafico,1,n,r)!=n) return 0;
   double maxJ=-DBL_MAX, minJ=DBL_MAX; int iMax=0, iMin=0;
   for(int i=0;i<n;i++) { if(r[i].high>maxJ) { maxJ=r[i].high; iMax=i; } if(r[i].low<minJ) { minJ=r[i].low; iMin=i; } }
   if((maxJ-minJ)/_Point<MovimentoMinimoPontos) return 0;
   MqlRates u=r[n-1];
   double amp=u.high-u.low; if(amp<=0) return 0;
   double corpo=(u.close-u.open)/amp;
   bool quedaAntes=(iMax<iMin);   // topo antes do fundo = movimento de queda
   int lado=0;
   if(ModoSinal==SINAL_REVERSAO)
   {
      if(quedaAntes && corpo>=CorpoMinimoReacao) lado=1;          // caiu e reagiu para cima
      else if(!quedaAntes && -corpo>=CorpoMinimoReacao) lado=-1;  // subiu e reagiu para baixo
   }
   else
   {
      if(!quedaAntes && corpo>=CorpoMinimoReacao) lado=1;
      else if(quedaAntes && -corpo>=CorpoMinimoReacao) lado=-1;
   }
   return lado;
}

bool Abrir(const int lado, const string comentario)
{
   MqlTick t; if(!SymbolInfoTick(_Symbol,t)) return false;
   double v=Volume(Contratos), preco=(lado>0?t.ask:t.bid), margem=0;
   if(!OrderCalcMargin(lado>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,v,preco,margem) || margem>AccountInfoDouble(ACCOUNT_MARGIN_FREE)) { estado="Margem insuficiente"; return false; }
   bool ok=(lado>0?negociador.Buy(v,_Symbol,0,0,0,comentario):negociador.Sell(v,_Symbol,0,0,0,comentario));
   uint rc=negociador.ResultRetcode();
   if(!ok || (rc!=TRADE_RETCODE_DONE && rc!=TRADE_RETCODE_DONE_PARTIAL)) { estado="Ordem recusada: "+negociador.ResultRetcodeDescription(); Print(estado); return false; }
   precoUltimaEntrada=(negociador.ResultPrice()>0?negociador.ResultPrice():preco);
   historicoSujo=true;
   return true;
}

// Alvo / stop / trailing pelo preco medio (controlados pelo EA).
bool GerenciarSaida(const Cesta &c)
{
   MqlTick t; if(!SymbolInfoTick(_Symbol,t)) return false;
   double preco=(c.lado>0?t.bid:t.ask);
   double pts=(c.lado>0?preco-c.precoMedio:c.precoMedio-preco)/_Point;
   if(AlvoPontos>0 && pts>=AlvoPontos) { FecharTudo(StringFormat("alvo +%.0f pts",pts)); return true; }
   double base=(BaseStop==STOP_PRIMEIRA?precoPrimeiraEntrada:c.precoMedio);
   double sl=base-c.lado*StopPontos*_Point;
   if(StopPontos>0 && (c.lado>0?preco<=sl:preco>=sl)) { FecharTudo(StringFormat("stop %.0f pts",pts)); return true; }
   if(TrailingInicioPontos>0 && pts>=TrailingInicioPontos)
   {
      double tr=preco-c.lado*TrailingDistanciaPontos*_Point;
      if(melhorSL==0 || (c.lado>0?tr>melhorSL:tr<melhorSL)) melhorSL=tr;
   }
   if(melhorSL!=0 && (c.lado>0?preco<=melhorSL:preco>=melhorSL)) { FecharTudo(StringFormat("trailing %.0f pts",pts)); return true; }
   return false;
}

//+------------------------------------------------------------------+
// Visual: painel no estilo do video (layout proprio) + linhas de nivel.
void Texto(const string id, const int x, const int y, const string s, const color cor, const int tam=8)
{
   string nome=prefixo+id;
   if(ObjectFind(0,nome)<0)
   {
      ObjectCreate(0,nome,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,nome,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetString(0,nome,OBJPROP_FONT,"Tahoma");
      ObjectSetInteger(0,nome,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nome,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,nome,OBJPROP_XDISTANCE,PainelX+x); ObjectSetInteger(0,nome,OBJPROP_YDISTANCE,PainelY+y);
   ObjectSetInteger(0,nome,OBJPROP_FONTSIZE,tam); ObjectSetInteger(0,nome,OBJPROP_COLOR,cor);
   ObjectSetString(0,nome,OBJPROP_TEXT,s);
}

void Linha(const string id, const double preco, const color cor, const ENUM_LINE_STYLE estilo)
{
   string nome=prefixo+id;
   if(preco<=0) { ObjectDelete(0,nome); return; }
   if(ObjectFind(0,nome)<0)
   {
      ObjectCreate(0,nome,OBJ_HLINE,0,0,preco);
      ObjectSetInteger(0,nome,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nome,OBJPROP_HIDDEN,true);
   }
   ObjectSetDouble(0,nome,OBJPROP_PRICE,preco);
   ObjectSetInteger(0,nome,OBJPROP_COLOR,cor);
   ObjectSetInteger(0,nome,OBJPROP_STYLE,estilo);
}

string Ef(const Estat &e) { return StringFormat("%d/%d(%s)",e.acertos,e.ciclos,e.ciclos>0?IntegerToString((int)MathRound(100.0*e.acertos/e.ciclos))+"%":"-"); }

void Painel()
{
   if(!visual) return;
   Cesta c; LerCesta(c);
   if(DesenharNiveis)
   {
      for(int k=1;k<=10;k++)
      {
         double p=0;
         if(c.n>0 && k<NiveisMaximos-niveisCiclo+1 && k<=NiveisMaximos) p=precoUltimaEntrada-c.lado*k*EspacamentoGradePontos*_Point;
         Linha("G"+IntegerToString(k),p,C'60,170,90',STYLE_DASH);
      }
      Linha("TP",c.n>0?c.precoMedio+c.lado*AlvoPontos*_Point:0,C'0,220,120',STYLE_SOLID);
      Linha("SL",c.n>0 && StopPontos>0?(BaseStop==STOP_PRIMEIRA?precoPrimeiraEntrada:c.precoMedio)-c.lado*StopPontos*_Point:0,C'220,50,50',STYLE_DASHDOT);
   }
   if(!ExibirPainel) { ChartRedraw(0); return; }
   string bg=prefixo+"BG";
   if(ObjectFind(0,bg)<0)
   {
      ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,C'14,32,62');
      ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,bg,OBJPROP_COLOR,C'70,110,170');
      ObjectSetInteger(0,bg,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,bg,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,PainelX); ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,PainelY);
   ObjectSetInteger(0,bg,OBJPROP_XSIZE,300); ObjectSetInteger(0,bg,OBJPROP_YSIZE,262);
   color rot=C'110,150,200', br=clrWhite, verde=C'80,230,120', verm=C'240,80,80';
   MqlTick t; SymbolInfoTick(_Symbol,t);
   Texto("T0",8,6,"EA14 PRECO REATIVO",C'120,230,120',10);
   Texto("A0",8,26,"Hora servidor",rot); Texto("A1",110,26,"Ativo",rot); Texto("A2",200,26,"Preco",rot);
   Texto("B0",8,40,TimeToString(TimeCurrent(),TIME_SECONDS),br,9); Texto("B1",110,40,_Symbol,br,9); Texto("B2",200,40,DoubleToString(t.bid,_Digits),br,9);
   Texto("C0",8,58,"Spread: "+IntegerToString((int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)),rot);
   Texto("C1",110,58,"Eficiencia",rot); Texto("C2",200,58,"Resultado",rot);
   string nomes[4]={"Dia","Semana","Mes","Total"};
   Estat es[4]; es[0]=eDia; es[1]=eSemana; es[2]=eMes; es[3]=eTotal;
   for(int i=0;i<4;i++)
   {
      Texto("D"+IntegerToString(i),8,72+i*14,nomes[i],rot,9);
      Texto("E"+IntegerToString(i),110,72+i*14,Ef(es[i]),es[i].lucro>=0?verde:verm,9);
      Texto("F"+IntegerToString(i),200,72+i*14,DoubleToString(es[i].lucro,2),es[i].lucro>=0?verde:verm,9);
   }
   Texto("G0",8,134,"Conta",rot); Texto("G1",110,134,"Lucro aberto",rot); Texto("G2",200,134,"Niveis",rot);
   Texto("H0",8,148,contaNetting?"Netting":"Hedging",br,9);
   Texto("H1",110,148,DoubleToString(c.lucro,2),c.lucro>=0?verde:verm,9);
   Texto("H2",200,148,StringFormat("%d/%d",c.n>0?niveisCiclo:0,NiveisMaximos),br,9);
   Texto("I0",8,168,"Lado",rot); Texto("I1",60,168,"Volume",rot); Texto("I2",120,168,"Preco medio",rot); Texto("I3",200,168,"Pontos",rot);
   double pts=0; if(c.n>0) pts=(c.lado>0?t.bid-c.precoMedio:c.precoMedio-t.ask)/_Point;
   Texto("J0",8,182,"Buy",C'80,160,255',9);  Texto("J1",60,182,DoubleToString(c.lado>0?c.vol:0,2),br,9);
   Texto("J2",120,182,c.lado>0?DoubleToString(c.precoMedio,0):"0",br,9); Texto("J3",200,182,c.lado>0?DoubleToString(pts,0):"0",pts>=0?verde:verm,9);
   Texto("K0",8,196,"Sell",C'240,120,80',9); Texto("K1",60,196,DoubleToString(c.lado<0?c.vol:0,2),br,9);
   Texto("K2",120,196,c.lado<0?DoubleToString(c.precoMedio,0):"0",br,9); Texto("K3",200,196,c.lado<0?DoubleToString(pts,0):"0",pts>=0?verde:verm,9);
   string bt=prefixo+"ZERAR";
   if(ObjectFind(0,bt)<0)
   {
      ObjectCreate(0,bt,OBJ_BUTTON,0,0,0);
      ObjectSetInteger(0,bt,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetString(0,bt,OBJPROP_TEXT,"Zerar");
      ObjectSetInteger(0,bt,OBJPROP_BGCOLOR,C'140,230,140');
      ObjectSetInteger(0,bt,OBJPROP_COLOR,C'20,60,20');
      ObjectSetInteger(0,bt,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,bt,OBJPROP_XDISTANCE,PainelX+20); ObjectSetInteger(0,bt,OBJPROP_YDISTANCE,PainelY+214);
   ObjectSetInteger(0,bt,OBJPROP_XSIZE,260); ObjectSetInteger(0,bt,OBJPROP_YSIZE,20);
   Texto("S0",8,242,"Estado: "+estado,C'230,210,120');
   ChartRedraw(0);
}

void LimparObjetos() { for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--) { string n=ObjectName(0,i,0,-1); if(StringFind(n,prefixo)==0) ObjectDelete(0,n); } }

//+------------------------------------------------------------------+
int OnInit()
{
   minInicio=ConverterHorario(HoraInicio); minFim=ConverterHorario(HoraFim); minZeragem=ConverterHorario(HoraZeragem);
   if(minInicio==-2 || minFim==-2 || minZeragem==-2) { Print("Horario invalido (HH:MM ou 0)."); return INIT_PARAMETERS_INCORRECT; }
   if(JanelaVelas<2 || MovimentoMinimoPontos<0 || CorpoMinimoReacao<0 || CorpoMinimoReacao>1 || Contratos<=0 ||
      EspacamentoGradePontos<=0 || NiveisMaximos<1 || NiveisMaximos>10 || AlvoPontos<=0 || StopPontos<0 ||
      TrailingInicioPontos<0 || TrailingDistanciaPontos<0 || PerdaMaximaDia<0 || GanhoMaximoDia<0 || CiclosMaximosDia<0)
   { Print("Parametros invalidos (niveis entre 1 e 10, corpo entre 0 e 1)."); return INIT_PARAMETERS_INCORRECT; }
   if(StopPontos>0 && BaseStop==STOP_PRIMEIRA && StopPontos<=(NiveisMaximos-1)*EspacamentoGradePontos)
      Print("ATENCAO: o stop fica antes do ultimo nivel da grade; os niveis alem do stop nunca serao usados.");
   contaNetting=((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   negociador.SetExpertMagicNumber((ulong)NumeroMagico);
   negociador.SetDeviationInPoints((ulong)DesvioMaximoPontos);
   negociador.SetTypeFillingBySymbol(_Symbol);
   negociador.LogLevel(LOG_LEVEL_ERRORS);
   prefixo="EA14_"+IntegerToString(NumeroMagico)+"_";
   // Retoma um ciclo aberto (ex.: reinicio do terminal).
   Cesta c; LerCesta(c);
   if(c.n>0)
   {
      precoPrimeiraEntrada=(GlobalVariableCheck(prefixo+"P1")?GlobalVariableGet(prefixo+"P1"):c.precoPrimeira);
      precoUltimaEntrada=(GlobalVariableCheck(prefixo+"PU")?GlobalVariableGet(prefixo+"PU"):c.precoUltima);
      niveisCiclo=(GlobalVariableCheck(prefixo+"N")?(int)GlobalVariableGet(prefixo+"N"):(int)MathRound(c.vol/Volume(Contratos)));
   }
   visual=(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE));
   if(visual)
   {
      ChartSetInteger(0,CHART_FOREGROUND,false);
      EventSetTimer(1);
      estado=(AmbientePermitido()?"Aguardando":"Bloqueado neste ambiente (grupo 01)");
      AtualizarHistorico(); Painel();
   }
   PrintFormat("EA14 iniciado (%s): %s, janela %d velas, movimento %d pts, %.0f contratos, grade %d pts x %d niveis, alvo %d, stop %d",
               contaNetting?"NETTING":"HEDGING",ModoSinal==SINAL_REVERSAO?"reversao":"continuacao",JanelaVelas,MovimentoMinimoPontos,
               Contratos,EspacamentoGradePontos,NiveisMaximos,AlvoPontos,StopPontos);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int r) { if(visual) { EventKillTimer(); LimparObjetos(); ChartRedraw(0); } }
void OnTimer() { AtualizarHistorico(); Painel(); }
void OnTradeTransaction(const MqlTradeTransaction &tr,const MqlTradeRequest &rq,const MqlTradeResult &rs) { if(tr.type==TRADE_TRANSACTION_DEAL_ADD) historicoSujo=true; }
void OnChartEvent(const int id,const long &l,const double &d,const string &s)
{
   if(id==CHARTEVENT_OBJECT_CLICK && s==prefixo+"ZERAR")
   {
      ObjectSetInteger(0,s,OBJPROP_STATE,false);
      FecharTudo("botao Zerar"); estado="Zerado pelo botao"; Painel();
   }
}
double OnTester()
{
   double ops=TesterStatistics(STAT_TRADES), lucro=TesterStatistics(STAT_PROFIT), dd=TesterStatistics(STAT_EQUITY_DD), pf=TesterStatistics(STAT_PROFIT_FACTOR);
   if(ops<30 || lucro<=0) return 0; if(dd<=0) dd=1; return lucro/dd*MathMin(pf,5.0);
}

void SalvarEstado() { GlobalVariableSet(prefixo+"P1",precoPrimeiraEntrada); GlobalVariableSet(prefixo+"PU",precoUltimaEntrada); GlobalVariableSet(prefixo+"N",niveisCiclo); }

void OnTick()
{
   AtualizarHistorico();
   if(!AmbientePermitido()) { estado="Bloqueado neste ambiente (grupo 01)"; return; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED)) { estado="Algotrading desligado"; return; }

   Cesta c; LerCesta(c);
   if(c.n==0 && niveisCiclo>0)
   {  // ciclo terminou (alvo, stop, zeragem ou botao)
      niveisCiclo=0; melhorSL=0; precoPrimeiraEntrada=precoUltimaEntrada=0; fimUltimoCiclo=TimeCurrent();
      GlobalVariableDel(prefixo+"P1"); GlobalVariableDel(prefixo+"PU"); GlobalVariableDel(prefixo+"N");
      historicoSujo=true;
   }

   if(minZeragem>=0 && MinutoAtual()>=minZeragem) { if(c.n>0) FecharTudo("zeragem"); estado="Horario de zeragem"; return; }

   if(c.n>0)
   {
      if(precoPrimeiraEntrada<=0) precoPrimeiraEntrada=c.precoPrimeira;
      if(precoUltimaEntrada<=0) precoUltimaEntrada=c.precoUltima;
      if(niveisCiclo<=0) niveisCiclo=1;
      if(GerenciarSaida(c)) return;
      // Grade: novo nivel quando o preco anda X pontos contra a ultima entrada.
      MqlTick t; if(!SymbolInfoTick(_Symbol,t)) return;
      double precoContra=(c.lado>0?t.ask:t.bid);
      bool contra=(c.lado>0?precoContra<=precoUltimaEntrada-EspacamentoGradePontos*_Point:precoContra>=precoUltimaEntrada+EspacamentoGradePontos*_Point);
      if(contra && niveisCiclo<NiveisMaximos && Abrir(c.lado,"EA14 nivel "+IntegerToString(niveisCiclo+1)))
      { niveisCiclo++; SalvarEstado(); Print(StringFormat("EA14: nivel %d em %s",niveisCiclo,DoubleToString(precoUltimaEntrada,_Digits))); }
      estado=StringFormat("%s %.0f contr. | medio %s | nivel %d/%d",c.lado>0?"Comprado":"Vendido",c.vol,DoubleToString(c.precoMedio,_Digits),niveisCiclo,NiveisMaximos);
      return;
   }

   // Sem posicao: novo ciclo (uma vez por vela).
   datetime barra=iTime(_Symbol,TempoGrafico,0);
   if(barra==ultimaBarra) return;
   ultimaBarra=barra;
   int agora=MinutoAtual(), ini=(minInicio<0?0:minInicio), fim=(minFim<0?24*60:minFim);
   if(!(ini<=fim?(agora>=ini && agora<fim):(agora>=ini || agora<fim))) { estado="Fora do horario"; return; }
   if(CiclosMaximosDia>0 && eDia.ciclos>=CiclosMaximosDia) { estado="Limite de ciclos do dia"; return; }
   if(PerdaMaximaDia>0 && eDia.lucro<=-PerdaMaximaDia) { estado="Perda maxima do dia"; return; }
   if(GanhoMaximoDia>0 && eDia.lucro>=GanhoMaximoDia) { estado="Meta do dia"; return; }
   if(fimUltimoCiclo>0 && TimeCurrent()-fimUltimoCiclo<EsperaAposCicloVelas*PeriodSeconds(TempoGrafico)) { estado="Espera apos ciclo"; return; }
   int s=Sinal();
   if(s==0) { estado="Aguardando reacao do preco"; return; }
   if((s>0 && !PermitirCompras) || (s<0 && !PermitirVendas)) return;
   for(int i=PositionsTotal()-1;i>=0;i--) { ulong tk=PositionGetTicket(i); if(tk>0 && PositionSelectByTicket(tk) && PositionGetString(POSITION_SYMBOL)==_Symbol) { estado="Outra posicao no ativo"; return; } }
   if(Abrir(s,"EA14 nivel 1"))
   {
      niveisCiclo=1; melhorSL=0; precoPrimeiraEntrada=precoUltimaEntrada; SalvarEstado();
      Print(StringFormat("EA14: %s %.0f contratos em %s (reacao)",s>0?"compra":"venda",Contratos,DoubleToString(precoPrimeiraEntrada,_Digits)));
   }
}
//+------------------------------------------------------------------+
