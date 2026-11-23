//+------------------------------------------------------------------+
//| EA 13 - EMA Snowball (WIN, M5)                                    |
//|                                                                  |
//| Reconstrucao a partir de um video (WINQ22 M5, Genial, EMA 20     |
//| vermelha). O audio nao foi transcrito e o codigo original nao e  |
//| conhecido: NAO e o robo do video. Pontos inferidos estao         |
//| marcados com [INTERPRETADO].                                     |
//|                                                                  |
//| O que aparece no video (ordens e historico):                     |
//|  - 05/07 11:17: 2 vendas a mercado em 98625 + 3 "sell limit" em  |
//|    98675, 98750 e 98870 (escada a favor do preco esticar contra).|
//|    Stops comuns acima (99025/99115), alvos abaixo (98450/98380). |
//|    Os dois alvos foram atingidos: +35 e +48 (R$).                |
//|  - 06/07: 3 vendas em 99005, 99095 e 99185 (90 pts entre elas),  |
//|    todas com o MESMO stop 99360, que foi atingido (-159).        |
//|  - 07/07: 4 compras em 101825, 101825, 101775, 101755 com o      |
//|    mesmo alvo 101895/102000; todas no lucro.                     |
//|  - Painel: EMA-20, Amplitude 490, Distancia -15, Contagem.       |
//|                                                                  |
//| Logica deste EA:                                                 |
//|  1) Tendencia: as ultimas N velas fechadas do mesmo lado da EMA  |
//|     ("Contagem") [INTERPRETADO].                                 |
//|  2) Gatilho: preco volta para perto da EMA (|distancia| <= X     |
//|     pontos) sem cruzar contra a tendencia ("Distancia").         |
//|  3) Entrada a mercado + escada de ordens limitadas contra o      |
//|    movimento (a "bola de neve").                                 |
//|  4) Stop comum a todas as ordens ("Amplitude" = distancia do     |
//|    stop a partir da 1a entrada) e alvo em pontos sobre o preco   |
//|    medio. A escada e cancelada quando o ciclo termina.           |
//+------------------------------------------------------------------+
#property version   "1.00"
#property description "EA13: pullback na EMA com escada de ordens e stop comum. Reconstrucao a partir de video; nao e o robo original."
#include <Trade/Trade.mqh>

input group "01 - GERAL"
input long   NumeroMagico = 6969;               // Numero magico
input bool   PermitirNoTestador = true;         // Operar no testador
input bool   PermitirEmDemo = false;            // Operar em conta demo
input bool   PermitirEmContaReal = false;       // Operar em conta real (bloqueado por padrao)
input ENUM_TIMEFRAMES TempoGrafico = PERIOD_M5; // Tempo grafico da EMA
input bool   PermitirCompras = true;            // Operar compras
input bool   PermitirVendas = true;             // Operar vendas

input group "02 - SINAL (EMA)"
input int    PeriodoEMA = 20;                   // Periodo da EMA
input int    ContagemVelas = 10;                // Velas fechadas seguidas do mesmo lado da EMA
input int    DistanciaEntradaPontos = 30;       // Entra quando o preco chega a X pontos da EMA
input int    EsperaAposCicloVelas = 3;          // Velas de espera depois de um ciclo

input group "03 - ENTRADA E ESCADA"
input double ContratosMercado = 2;              // Contratos a mercado no gatilho
input string DistanciasEscada = "50,125,245";   // Pontos contra a entrada de cada ordem limitada (vazio = sem escada)
input double ContratosPorDegrau = 1;            // Contratos de cada ordem da escada

input group "04 - STOP E ALVO (pontos)"
input int    AmplitudeStopPontos = 490;         // Stop comum: X pontos da 1a entrada
input int    AlvoPontos = 200;                  // Alvo: X pontos a favor do preco medio
input int    BreakEvenPontos = 0;               // Leva o stop ao preco medio apos X pontos (0 desliga)

input group "05 - HORARIO E LIMITES"
input string HoraInicio = "09:15";              // Inicio das entradas (HH:MM)
input string HoraFim = "16:30";                 // Fim das entradas (HH:MM)
input string HoraZeragem = "17:45";             // Zeragem (HH:MM); 0 desliga
input int    CiclosMaximosDia = 3;              // Ciclos por dia (0 = sem limite)
input double PerdaMaximaDia = 300;              // Para no dia ao perder R$ X (0 desliga)
input double GanhoMaximoDia = 0;                // Para no dia ao ganhar R$ X (0 desliga)
input int    DesvioMaximoPontos = 20;           // Desvio maximo na execucao

input group "06 - VISUAL"
input bool   ExibirPainel = true;               // Painel
input bool   DesenharEMA = true;                // Adiciona a EMA ao grafico
input int    PainelX = 10;                      // Posicao horizontal
input int    PainelY = 20;                      // Posicao vertical

struct Cesta { int lado; int n; double vol; double precoMedio; double lucro; double precoPrimeira; };

CTrade negociador;
int hEMA=INVALID_HANDLE;
string prefixo, estado="Iniciando";
bool visual=false, contaNetting=false;
int minInicio=-1, minFim=-1, minZeragem=-1;
double degraus[];
datetime ultimaBarra=0, fimUltimoCiclo=0;
double precoPrimeiraEntrada=0;
int ladoCiclo=0;

bool historicoSujo=true;
double resultadoDia=0, resultadoMes=0; int ciclosDia=0, acertosDia=0, ciclosMes=0, acertosMes=0;
double emaAtual=0, distanciaAtual=0; int contagemAtual=0;

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
   c.lado=0; c.n=0; c.vol=0; c.precoMedio=0; c.lucro=0; c.precoPrimeira=0;
   double soma=0; long primeiro=LONG_MAX;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0 || !PositionSelectByTicket(tk) || !MinhaPosicao()) continue;
      double v=PositionGetDouble(POSITION_VOLUME), p=PositionGetDouble(POSITION_PRICE_OPEN);
      c.lado=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1);
      c.n++; c.vol+=v; soma+=v*p; c.lucro+=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      long t=PositionGetInteger(POSITION_TIME_MSC);
      if(t<primeiro) { primeiro=t; c.precoPrimeira=p; }
   }
   if(c.vol>0) c.precoMedio=soma/c.vol;
}

int PendentesDoEA()
{
   int q=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong tk=OrderGetTicket(i);
      if(tk>0 && OrderSelect(tk) && OrderGetString(ORDER_SYMBOL)==_Symbol && OrderGetInteger(ORDER_MAGIC)==NumeroMagico) q++;
   }
   return q;
}

void CancelarPendentes()
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong tk=OrderGetTicket(i);
      if(tk>0 && OrderSelect(tk) && OrderGetString(ORDER_SYMBOL)==_Symbol && OrderGetInteger(ORDER_MAGIC)==NumeroMagico)
         negociador.OrderDelete(tk);
   }
}

void FecharTudo(const string motivo)
{
   CancelarPendentes();
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk>0 && PositionSelectByTicket(tk) && MinhaPosicao()) negociador.PositionClose(tk);
   }
   historicoSujo=true;
   Print("EA13: ciclo encerrado (",motivo,")");
}

// Coloca o stop comum e o alvo sobre o preco medio em todas as posicoes.
void AjustarStops(const Cesta &c)
{
   if(c.n==0 || precoPrimeiraEntrada<=0) return;
   double sl=Ajustar(precoPrimeiraEntrada-c.lado*AmplitudeStopPontos*_Point);
   double tp=Ajustar(c.precoMedio+c.lado*AlvoPontos*_Point);
   MqlTick t; if(!SymbolInfoTick(_Symbol,t)) return;
   if(BreakEvenPontos>0 && (c.lado>0?t.bid-c.precoMedio:c.precoMedio-t.ask)>=BreakEvenPontos*_Point)
      sl=Ajustar(c.lado>0?MathMax(sl,c.precoMedio+_Point*5):MathMin(sl,c.precoMedio-_Point*5));
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0 || !PositionSelectByTicket(tk) || !MinhaPosicao()) continue;
      if(MathAbs(PositionGetDouble(POSITION_SL)-sl)<_Point/2 && MathAbs(PositionGetDouble(POSITION_TP)-tp)<_Point/2) continue;
      if(!negociador.PositionModify(tk,sl,tp)) PrintFormat("EA13: falha ao ajustar SL/TP: %s",negociador.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
// Ciclos = saidas agrupadas pelo mesmo segundo (o stop/alvo comum fecha tudo junto).
void AtualizarHistorico()
{
   if(!historicoSujo) return;
   datetime hoje=InicioDia(TimeCurrent()), mes=InicioMes(TimeCurrent());
   resultadoDia=resultadoMes=0; ciclosDia=acertosDia=ciclosMes=acertosMes=0;
   if(HistorySelect(mes,TimeCurrent()+86400))
   {
      datetime tAtual=0; double rAtual=0;
      for(int i=0;i<=HistoryDealsTotal();i++)
      {
         bool fim=(i==HistoryDealsTotal());
         ulong d=fim?0:HistoryDealGetTicket(i);
         datetime t=0; double r=0; bool saida=false;
         if(!fim && d>0 && HistoryDealGetString(d,DEAL_SYMBOL)==_Symbol && HistoryDealGetInteger(d,DEAL_MAGIC)==NumeroMagico)
         {
            long tp=HistoryDealGetInteger(d,DEAL_TYPE);
            if(tp==DEAL_TYPE_BUY || tp==DEAL_TYPE_SELL)
            {
               r=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_COMMISSION)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_FEE);
               t=(datetime)HistoryDealGetInteger(d,DEAL_TIME);
               saida=(HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_IN);
               resultadoMes+=r; if(t>=hoje) resultadoDia+=r;
            }
         }
         if((fim || (saida && MathAbs((long)(t-tAtual))>2)) && tAtual>0)
         {
            ciclosMes++; if(rAtual>0) acertosMes++;
            if(tAtual>=hoje) { ciclosDia++; if(rAtual>0) acertosDia++; }
            tAtual=0; rAtual=0;
         }
         if(saida) { tAtual=t; rAtual+=r; }
      }
   }
   historicoSujo=false;
}

//+------------------------------------------------------------------+
// Sinal: 1 compra, -1 venda, 0 nada.
int Sinal()
{
   int n=MathMax(2,ContagemVelas);
   double ema[]; MqlRates r[];
   if(CopyBuffer(hEMA,0,0,n+1,ema)!=n+1 || CopyRates(_Symbol,TempoGrafico,0,n+1,r)!=n+1) return 0;
   // r[n] e ema[n] = vela atual (aberta); r[0..n-1] = fechadas.
   int acima=0, abaixo=0;
   for(int i=n-1;i>=0;i--)
   {
      if(r[i].close>ema[i]) { if(abaixo>0) break; acima++; }
      else if(r[i].close<ema[i]) { if(acima>0) break; abaixo++; }
      else break;
   }
   contagemAtual=(acima>0?acima:-abaixo);
   emaAtual=ema[n];
   MqlTick t; if(!SymbolInfoTick(_Symbol,t)) return 0;
   double preco=(t.bid+t.ask)/2;
   distanciaAtual=(preco-emaAtual)/_Point;
   // Compra: tendencia de alta e o preco voltou ate a EMA, ainda por cima dela.
   if(acima>=ContagemVelas && distanciaAtual>=0 && distanciaAtual<=DistanciaEntradaPontos) return 1;
   if(abaixo>=ContagemVelas && distanciaAtual<=0 && -distanciaAtual<=DistanciaEntradaPontos) return -1;
   return 0;
}

bool AbrirCiclo(const int lado)
{
   MqlTick t; if(!SymbolInfoTick(_Symbol,t)) return false;
   double entrada=(lado>0?t.ask:t.bid);
   double sl=Ajustar(entrada-lado*AmplitudeStopPontos*_Point);
   double tp=Ajustar(entrada+lado*AlvoPontos*_Point);
   double v=Volume(ContratosMercado);
   double margem=0;
   if(!OrderCalcMargin(lado>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,v,entrada,margem) || margem>AccountInfoDouble(ACCOUNT_MARGIN_FREE)) { estado="Margem insuficiente"; return false; }
   bool ok=(lado>0?negociador.Buy(v,_Symbol,0,sl,tp,"EA13 entrada"):negociador.Sell(v,_Symbol,0,sl,tp,"EA13 entrada"));
   if(!ok || (negociador.ResultRetcode()!=TRADE_RETCODE_DONE && negociador.ResultRetcode()!=TRADE_RETCODE_DONE_PARTIAL))
   { estado="Ordem recusada: "+negociador.ResultRetcodeDescription(); Print(estado); return false; }
   precoPrimeiraEntrada=(negociador.ResultPrice()>0?negociador.ResultPrice():entrada);
   ladoCiclo=lado;
   GlobalVariableSet(prefixo+"P1",precoPrimeiraEntrada);
   // Escada: ordens limitadas contra o movimento, sem SL/TP proprios (o EA ajusta ao executar).
   for(int i=0;i<ArraySize(degraus);i++)
   {
      double p=Ajustar(precoPrimeiraEntrada-lado*degraus[i]*_Point);
      if(lado>0 && p<=sl) continue;
      if(lado<0 && p>=sl) continue;
      bool okL=(lado>0?negociador.BuyLimit(Volume(ContratosPorDegrau),p,_Symbol,0,0,ORDER_TIME_DAY,0,"EA13 escada "+IntegerToString(i+1))
                      :negociador.SellLimit(Volume(ContratosPorDegrau),p,_Symbol,0,0,ORDER_TIME_DAY,0,"EA13 escada "+IntegerToString(i+1)));
      if(!okL) PrintFormat("EA13: degrau %d recusado: %s",i+1,negociador.ResultRetcodeDescription());
   }
   historicoSujo=true;
   estado=StringFormat("%s em %s + escada de %d ordens",lado>0?"Compra":"Venda",DoubleToString(precoPrimeiraEntrada,_Digits),ArraySize(degraus));
   Print("EA13: ",estado);
   return true;
}

//+------------------------------------------------------------------+
void Rotulo(const int linha, const string s, const color cor)
{
   string nome=prefixo+"L"+IntegerToString(linha);
   if(ObjectFind(0,nome)<0)
   {
      ObjectCreate(0,nome,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,nome,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetString(0,nome,OBJPROP_FONT,"Courier New");
      ObjectSetInteger(0,nome,OBJPROP_FONTSIZE,9);
      ObjectSetInteger(0,nome,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nome,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,nome,OBJPROP_XDISTANCE,PainelX+8);
   ObjectSetInteger(0,nome,OBJPROP_YDISTANCE,PainelY+6+linha*16);
   ObjectSetInteger(0,nome,OBJPROP_COLOR,cor);
   ObjectSetString(0,nome,OBJPROP_TEXT,s);
}

void Painel()
{
   if(!visual || !ExibirPainel) return;
   string bg=prefixo+"BG";
   if(ObjectFind(0,bg)<0)
   {
      ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,C'245,245,240');
      ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,bg,OBJPROP_COLOR,C'120,120,120');
      ObjectSetInteger(0,bg,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,bg,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,PainelX); ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,PainelY);
   ObjectSetInteger(0,bg,OBJPROP_XSIZE,290); ObjectSetInteger(0,bg,OBJPROP_YSIZE,13*16+10);
   Cesta c; LerCesta(c);
   long seg=PeriodSeconds(TempoGrafico)-(long)(TimeCurrent()-iTime(_Symbol,TempoGrafico,0)); if(seg<0) seg=0;
   color k=C'60,60,60', azul=C'40,60,200';
   Rotulo(0,"EXPERT...... EA13 EMA Snowball",azul);
   Rotulo(1,"MAGICO...... "+IntegerToString(NumeroMagico),k);
   Rotulo(2,StringFormat("TEMPO VELA.. %02d:%02d",(int)(seg/60),(int)(seg%60)),k);
   Rotulo(3,StringFormat("POSICAO..... %s %.0f @ %s",c.lado>0?"COMPRA":c.lado<0?"VENDA":"-",c.vol,c.n>0?DoubleToString(c.precoMedio,_Digits):"-"),c.lado>0?C'0,120,200':c.lado<0?C'200,40,40':k);
   Rotulo(4,StringFormat("LUCRO ABERTO %.2f | escada pendente: %d",c.lucro,PendentesDoEA()),c.lucro>=0?C'0,140,60':C'200,40,40');
   Rotulo(5,StringFormat("DIA......... %.2f (%d/%d)",resultadoDia,acertosDia,ciclosDia),resultadoDia>=0?C'0,140,60':C'200,40,40');
   Rotulo(6,StringFormat("MES......... %.2f (%d/%d)",resultadoMes,acertosMes,ciclosMes),resultadoMes>=0?C'0,140,60':C'200,40,40');
   Rotulo(7," ",k);
   Rotulo(8,StringFormat("EMA-%d...... %s",PeriodoEMA,DoubleToString(emaAtual,_Digits)),C'200,40,40');
   Rotulo(9,StringFormat("DISTANCIA... %.0f pts (gatilho %d)",distanciaAtual,DistanciaEntradaPontos),azul);
   Rotulo(10,StringFormat("CONTAGEM.... %d velas (minimo %d)",MathAbs(contagemAtual),ContagemVelas),azul);
   Rotulo(11,StringFormat("AMPLITUDE... %d | ALVO %d",AmplitudeStopPontos,AlvoPontos),azul);
   Rotulo(12,"SITUACAO.... "+estado,k);
   ChartRedraw(0);
}

void LimparObjetos() { for(int i=ObjectsTotal(0,0,-1)-1;i>=0;i--) { string n=ObjectName(0,i,0,-1); if(StringFind(n,prefixo)==0) ObjectDelete(0,n); } }

//+------------------------------------------------------------------+
int OnInit()
{
   minInicio=ConverterHorario(HoraInicio); minFim=ConverterHorario(HoraFim); minZeragem=ConverterHorario(HoraZeragem);
   if(minInicio==-2 || minFim==-2 || minZeragem==-2) { Print("Horario invalido (HH:MM ou 0)."); return INIT_PARAMETERS_INCORRECT; }
   if(PeriodoEMA<2 || ContagemVelas<1 || DistanciaEntradaPontos<0 || ContratosMercado<=0 || ContratosPorDegrau<=0 ||
      AmplitudeStopPontos<=0 || AlvoPontos<=0 || CiclosMaximosDia<0 || PerdaMaximaDia<0 || GanhoMaximoDia<0)
   { Print("Parametros invalidos."); return INIT_PARAMETERS_INCORRECT; }
   ArrayResize(degraus,0);
   string partes[]; int np=StringSplit(DistanciasEscada,StringGetCharacter(",",0),partes);
   for(int i=0;i<np;i++)
   {
      string s=partes[i]; StringTrimLeft(s); StringTrimRight(s);
      if(s=="") continue;
      double v=StringToDouble(s);
      if(v<=0 || v>=AmplitudeStopPontos) { Print("Degrau da escada invalido (deve ficar entre 0 e a amplitude do stop): ",s); return INIT_PARAMETERS_INCORRECT; }
      int k=ArraySize(degraus); ArrayResize(degraus,k+1); degraus[k]=v;
   }
   hEMA=iMA(_Symbol,TempoGrafico,PeriodoEMA,0,MODE_EMA,PRICE_CLOSE);
   if(hEMA==INVALID_HANDLE) { Print("Falha ao criar a EMA."); return INIT_FAILED; }
   contaNetting=((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   negociador.SetExpertMagicNumber((ulong)NumeroMagico);
   negociador.SetDeviationInPoints((ulong)DesvioMaximoPontos);
   negociador.SetTypeFillingBySymbol(_Symbol);
   negociador.LogLevel(LOG_LEVEL_ERRORS);
   prefixo="EA13_"+IntegerToString(NumeroMagico)+"_";
   if(GlobalVariableCheck(prefixo+"P1")) precoPrimeiraEntrada=GlobalVariableGet(prefixo+"P1");
   visual=(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE));
   if(visual)
   {
      ChartSetInteger(0,CHART_FOREGROUND,false);
      if(DesenharEMA && TempoGrafico==Period()) ChartIndicatorAdd(0,0,hEMA);
      EventSetTimer(1);
      estado=(AmbientePermitido()?"Aguardando":"Bloqueado neste ambiente (grupo 01)");
      AtualizarHistorico(); Painel();
   }
   PrintFormat("EA13 iniciado (%s): EMA %d, contagem %d, distancia %d, escada [%s], stop %d, alvo %d",
               contaNetting?"NETTING":"HEDGING",PeriodoEMA,ContagemVelas,DistanciaEntradaPontos,DistanciasEscada,AmplitudeStopPontos,AlvoPontos);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int r) { if(visual) { EventKillTimer(); LimparObjetos(); ChartRedraw(0); } IndicatorRelease(hEMA); }
void OnTimer() { AtualizarHistorico(); Painel(); }
void OnTradeTransaction(const MqlTradeTransaction &tr,const MqlTradeRequest &rq,const MqlTradeResult &rs) { if(tr.type==TRADE_TRANSACTION_DEAL_ADD) historicoSujo=true; }
double OnTester()
{
   double ops=TesterStatistics(STAT_TRADES), lucro=TesterStatistics(STAT_PROFIT), dd=TesterStatistics(STAT_EQUITY_DD), pf=TesterStatistics(STAT_PROFIT_FACTOR);
   if(ops<30 || lucro<=0) return 0; if(dd<=0) dd=1; return lucro/dd*MathMin(pf,5.0);
}

void OnTick()
{
   AtualizarHistorico();
   if(!AmbientePermitido()) { estado="Bloqueado neste ambiente (grupo 01)"; return; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED)) { estado="Algotrading desligado"; return; }

   Cesta c; LerCesta(c);
   int pend=PendentesDoEA();

   // Fim de ciclo: sem posicao -> cancela a escada que sobrou.
   if(c.n==0 && pend>0 && precoPrimeiraEntrada>0)
   { CancelarPendentes(); precoPrimeiraEntrada=0; ladoCiclo=0; GlobalVariableDel(prefixo+"P1"); fimUltimoCiclo=TimeCurrent(); historicoSujo=true; estado="Ciclo encerrado"; return; }
   if(c.n==0 && pend==0 && precoPrimeiraEntrada>0)
   { precoPrimeiraEntrada=0; ladoCiclo=0; GlobalVariableDel(prefixo+"P1"); fimUltimoCiclo=TimeCurrent(); historicoSujo=true; }

   // Zeragem.
   if(minZeragem>=0 && MinutoAtual()>=minZeragem) { if(c.n>0 || pend>0) FecharTudo("zeragem"); estado="Horario de zeragem"; return; }

   // Ciclo aberto: mantem stop comum e alvo no preco medio.
   if(c.n>0)
   {
      if(precoPrimeiraEntrada<=0) precoPrimeiraEntrada=c.precoPrimeira;
      AjustarStops(c);
      estado=StringFormat("Ciclo %s: %.0f contr. @ %s",c.lado>0?"comprado":"vendido",c.vol,DoubleToString(c.precoMedio,_Digits));
      return;
   }

   // Sem ciclo: procura sinal (uma vez por vela).
   datetime barra=iTime(_Symbol,TempoGrafico,0);
   int s=Sinal();
   if(barra==ultimaBarra) return;
   if(s==0) { estado="Aguardando pullback na EMA"; return; }
   if(fimUltimoCiclo>0 && TimeCurrent()-fimUltimoCiclo<EsperaAposCicloVelas*PeriodSeconds(TempoGrafico)) { estado="Espera apos ciclo"; return; }
   int agora=MinutoAtual(), ini=(minInicio<0?0:minInicio), fim=(minFim<0?24*60:minFim);
   if(!(ini<=fim?(agora>=ini && agora<fim):(agora>=ini || agora<fim))) { estado="Fora do horario"; return; }
   if(CiclosMaximosDia>0 && ciclosDia>=CiclosMaximosDia) { estado="Limite de ciclos do dia"; return; }
   if(PerdaMaximaDia>0 && resultadoDia<=-PerdaMaximaDia) { estado="Perda maxima do dia"; return; }
   if(GanhoMaximoDia>0 && resultadoDia>=GanhoMaximoDia) { estado="Meta do dia"; return; }
   if((s>0 && !PermitirCompras) || (s<0 && !PermitirVendas)) return;
   for(int i=PositionsTotal()-1;i>=0;i--) { ulong tk=PositionGetTicket(i); if(tk>0 && PositionSelectByTicket(tk) && PositionGetString(POSITION_SYMBOL)==_Symbol) { estado="Outra posicao no ativo"; return; } }
   if(AbrirCiclo(s)) ultimaBarra=barra;
}
//+------------------------------------------------------------------+
