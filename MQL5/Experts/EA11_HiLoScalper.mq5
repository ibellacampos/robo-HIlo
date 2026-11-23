//+------------------------------------------------------------------+
//| EA 11 - HiLo Scalper (WIN, M1)                                    |
//|                                                                  |
//| Reconstrucao a partir do que aparece em um video de operacao     |
//| (WINM25, grafico M1, linha HiLo azul/vermelha). O audio nao foi  |
//| transcrito e o codigo original nao e conhecido. NAO e o robo do  |
//| video: a logica abaixo e a interpretacao do que se ve na tela.   |
//|                                                                  |
//| O que foi observado no video:                                    |
//|  - Entrada quando o HiLo vira (azul = compra, vermelho = venda). |
//|  - Alvo e stop fixos; a posicao NAO e encerrada quando o HiLo    |
//|    vira contra (comprado com HiLo vermelho no video).            |
//|  - 2 contratos. Painel: dia 20/23 acertos, ganho R$480, perda    |
//|    R$180; mes 187/230, ganho R$4.418, perda R$2.620. Isso da     |
//|    ~R$24 por acerto e ~R$60 por erro com 2 contratos, ou seja,   |
//|    alvo ~60 pontos e stop ~150 pontos (valores ESTIMADOS).       |
//+------------------------------------------------------------------+
#property version   "1.00"
#property description "EA11: entrada na virada do HiLo com alvo e stop fixos. Reconstrucao a partir de video; nao e o robo original."
#include <Trade/Trade.mqh>

input group "01 - GERAL"
input long NumeroMagico = 31220;               // Numero magico
input bool PermitirNoTestador = true;          // Operar no testador
input bool PermitirEmDemo = false;             // Operar em conta demo
input bool PermitirEmContaReal = false;        // Operar em conta real (bloqueado por padrao)
input ENUM_TIMEFRAMES PeriodoDosSinais = PERIOD_M1; // Tempo grafico do HiLo
input double Contratos = 2;                    // Contratos por operacao
input int AlvoPontos = 60;                     // Take profit em pontos (estimado do video)
input int StopPontos = 150;                    // Stop loss em pontos (estimado do video)
input bool PermitirCompras = true;             // Operar viradas para cima
input bool PermitirVendas = true;              // Operar viradas para baixo
input bool MostrarDiagnosticos = true;         // Mensagens no Diario

input group "02 - HILO ACTIVATOR"
input int PeriodoHiLo = 10;                    // Periodo das medias de maximas e minimas
input ENUM_MA_METHOD MetodoHiLo = MODE_SMA;    // Metodo das medias
input bool SairNaViradaContraria = false;      // Fecha a posicao quando o HiLo vira contra (video: nao)

input group "03 - HORARIO (servidor) E ZERAGEM"
input string HoraInicio = "09:15";             // Inicio das entradas (HH:MM)
input string HoraFim = "17:00";                // Fim das entradas (HH:MM)
input string HoraZeragem = "17:45";            // Zera a posicao (HH:MM); 0 desliga

input group "04 - LIMITES DIARIOS | 0 desligado"
input double GanhoMaximoDia = 0.0;             // Para no dia ao ganhar R$X (fechado)
input double PerdaMaximaDia = 0.0;             // Para no dia ao perder R$X (fechado)
input int OperacoesMaximasDia = 0;             // Limite de entradas por dia
input int SpreadMaximoPontos = 0;              // Nao entra com spread maior
input int DesvioMaximoPontos = 20;             // Desvio maximo na execucao

input group "05 - VISUAL"
input bool ExibirPainel = true;                // Painel de resultados
input bool DesenharHiLo = true;                // Desenha a linha HiLo e as viradas
input int BarrasDesenhadas = 300;              // Quantas barras do HiLo manter desenhadas
input color CorCompra = C'30,144,255';         // Cor do HiLo de alta
input color CorVenda = C'230,60,60';           // Cor do HiLo de baixa
input int PainelX = 10;                        // Posicao horizontal do painel
input int PainelY = 20;                        // Posicao vertical do painel

input group "06 - OTIMIZACAO (OnTester)"
input int MinimoOperacoesOtimizacao = 50;      // Abaixo disso o criterio personalizado retorna 0

CTrade negociador;
int hMaxima=INVALID_HANDLE, hMinima=INVALID_HANDLE;
datetime ultimaBarra=0;
int tendenciaAtual=0;          // 1 alta, -1 baixa, 0 indefinida
double linhaAtual=0.0;
string prefixo;
bool visualDisponivel=false;
string estado="Iniciando";
int minInicio=-1, minFim=-1, minZeragem=-1;

// Estatisticas (recalculadas quando ha negocio novo ou muda o dia).
bool historicoSujo=true;
datetime diaHistorico=0;
double ganhoDia=0, perdaDia=0, ganhoMes=0, perdaMes=0;
int acertosDia=0, totalDia=0, acertosMes=0, totalMes=0, entradasDia=0;
double rebaixamentoPosicao=0.0;

// Objetos do HiLo desenhados (fila circular para limitar a quantidade).
string objetosHiLo[];
int proximoObjeto=0;

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

bool DentroDoHorario()
{
   int agora=MinutoAtual();
   int ini=(minInicio<0?0:minInicio), fim=(minFim<0?24*60:minFim);
   if(ini<=fim) return agora>=ini && agora<fim;
   return agora>=ini || agora<fim;
}

bool HorarioDeZeragem() { return minZeragem>=0 && MinutoAtual()>=minZeragem; }

double PrecoAjustado(const double preco)
{
   double passo=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(passo<=0) passo=_Point;
   return NormalizeDouble(MathRound(preco/passo)*passo,_Digits);
}

//+------------------------------------------------------------------+
// Posicao deste EA (uma por vez). Retorna 1 comprado, -1 vendido, 0 sem posicao.
int PosicaoDoEA(ulong &ticket, double &volume, double &lucro)
{
   ticket=0; volume=0; lucro=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk==0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol || PositionGetInteger(POSITION_MAGIC)!=NumeroMagico) continue;
      ticket=tk;
      volume=PositionGetDouble(POSITION_VOLUME);
      lucro=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      return (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1);
   }
   return 0;
}

bool ExistePosicaoNoAtivo()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i);
      if(tk>0 && PositionSelectByTicket(tk) && PositionGetString(POSITION_SYMBOL)==_Symbol) return true;
   }
   return false;
}

void FecharPosicao(const string motivo)
{
   ulong tk; double vol, luc;
   if(PosicaoDoEA(tk,vol,luc)==0) return;
   if(negociador.PositionClose(tk))
   {
      historicoSujo=true;
      if(MostrarDiagnosticos) PrintFormat("Posicao fechada (%s), resultado %.2f",motivo,luc);
   }
   else PrintFormat("Falha ao fechar posicao: %s",negociador.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
// Estatisticas do dia e do mes a partir dos negocios de SAIDA deste EA.
void AtualizarHistorico()
{
   datetime hoje=InicioDia(TimeCurrent());
   if(!historicoSujo && hoje==diaHistorico) return;
   ganhoDia=perdaDia=ganhoMes=perdaMes=0;
   acertosDia=totalDia=acertosMes=totalMes=entradasDia=0;
   if(HistorySelect(InicioMes(TimeCurrent()),TimeCurrent()+86400))
   {
      for(int i=0;i<HistoryDealsTotal();i++)
      {
         ulong tk=HistoryDealGetTicket(i);
         if(tk==0 || HistoryDealGetString(tk,DEAL_SYMBOL)!=_Symbol || HistoryDealGetInteger(tk,DEAL_MAGIC)!=NumeroMagico) continue;
         long tipo=HistoryDealGetInteger(tk,DEAL_TYPE);
         if(tipo!=DEAL_TYPE_BUY && tipo!=DEAL_TYPE_SELL) continue;
         bool hojeSim=((datetime)HistoryDealGetInteger(tk,DEAL_TIME)>=hoje);
         long entrada=HistoryDealGetInteger(tk,DEAL_ENTRY);
         if(entrada==DEAL_ENTRY_IN) { if(hojeSim) entradasDia++; continue; }
         double r=HistoryDealGetDouble(tk,DEAL_PROFIT)+HistoryDealGetDouble(tk,DEAL_COMMISSION)
                 +HistoryDealGetDouble(tk,DEAL_SWAP)+HistoryDealGetDouble(tk,DEAL_FEE);
         totalMes++; if(r>0) { acertosMes++; ganhoMes+=r; } else perdaMes+=-r;
         if(hojeSim) { totalDia++; if(r>0) { acertosDia++; ganhoDia+=r; } else perdaDia+=-r; }
      }
   }
   diaHistorico=hoje;
   historicoSujo=false;
}

//+------------------------------------------------------------------+
// HiLo Activator calculado sobre barras FECHADAS:
//   fechamento > media das maximas da barra anterior -> alta (linha = media das minimas)
//   fechamento < media das minimas da barra anterior -> baixa (linha = media das maximas)
//   caso contrario mantem a tendencia anterior.
// Preenche tendencia[] e linha[] em ordem cronologica (ultimo = barra 1).
bool CalcularHiLo(const int barras, int &tendencia[], double &linha[], datetime &tempos[])
{
   double maxs[], mins[], fech[];
   int n=barras+1;
   if(CopyBuffer(hMaxima,0,1,n,maxs)!=n || CopyBuffer(hMinima,0,1,n,mins)!=n ||
      CopyClose(_Symbol,PeriodoDosSinais,1,n,fech)!=n || CopyTime(_Symbol,PeriodoDosSinais,1,n,tempos)!=n)
      return false;
   ArrayResize(tendencia,n); ArrayResize(linha,n);
   int t=0;
   tendencia[0]=0; linha[0]=0;
   for(int j=1;j<n;j++)
   {
      if(fech[j]>maxs[j-1]) t=1;
      else if(fech[j]<mins[j-1]) t=-1;
      tendencia[j]=t;
      linha[j]=(t>0?mins[j-1]:t<0?maxs[j-1]:0.0);
   }
   return true;
}

//+------------------------------------------------------------------+
// Desenho do HiLo: um segmento por barra e um circulo em cada virada.
void GuardarObjeto(const string nome)
{
   int limite=MathMax(10,BarrasDesenhadas)*2;
   if(ArraySize(objetosHiLo)!=limite) { ArrayResize(objetosHiLo,limite); proximoObjeto=0; }
   if(objetosHiLo[proximoObjeto]!="" && objetosHiLo[proximoObjeto]!=nome) ObjectDelete(0,objetosHiLo[proximoObjeto]);
   objetosHiLo[proximoObjeto]=nome;
   proximoObjeto=(proximoObjeto+1)%limite;
}

void DesenharBarra(const datetime t0, const double v0, const datetime t1, const double v1,
                   const int tend, const bool virada)
{
   if(!visualDisponivel || !DesenharHiLo || tend==0 || v0<=0 || v1<=0) return;
   color cor=(tend>0?CorCompra:CorVenda);
   string nome=prefixo+"H"+IntegerToString((long)t1);
   if(ObjectFind(0,nome)<0)
   {
      // Na virada a linha "pula" para o outro lado: desenha so o degrau novo.
      ObjectCreate(0,nome,OBJ_TREND,0,t0,virada?v1:v0,t1,v1);
      ObjectSetInteger(0,nome,OBJPROP_COLOR,cor);
      ObjectSetInteger(0,nome,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,nome,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,nome,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nome,OBJPROP_HIDDEN,true);
      GuardarObjeto(nome);
   }
   if(virada)
   {
      string c=prefixo+"V"+IntegerToString((long)t1);
      if(ObjectFind(0,c)<0)
      {
         ObjectCreate(0,c,OBJ_ARROW,0,t1,v1);
         ObjectSetInteger(0,c,OBJPROP_ARROWCODE,159);
         ObjectSetInteger(0,c,OBJPROP_COLOR,cor);
         ObjectSetInteger(0,c,OBJPROP_WIDTH,3);
         ObjectSetInteger(0,c,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,c,OBJPROP_HIDDEN,true);
         GuardarObjeto(c);
      }
   }
}

void DesenharHistoricoHiLo()
{
   int tend[]; double lin[]; datetime tm[];
   int n=MathMax(10,BarrasDesenhadas);
   if(!CalcularHiLo(n,tend,lin,tm)) return;
   for(int j=2;j<ArraySize(tend);j++)
      DesenharBarra(tm[j-1],lin[j-1],tm[j],lin[j],tend[j],tend[j]!=tend[j-1] && tend[j-1]!=0);
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
// Painel proprio.
void Texto(const int linha, const int coluna, const string s, const color cor)
{
   string nome=prefixo+"P"+IntegerToString(linha)+"_"+IntegerToString(coluna);
   if(ObjectFind(0,nome)<0)
   {
      ObjectCreate(0,nome,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,nome,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetString(0,nome,OBJPROP_FONT,"Consolas");
      ObjectSetInteger(0,nome,OBJPROP_FONTSIZE,9);
      ObjectSetInteger(0,nome,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,nome,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,nome,OBJPROP_XDISTANCE,PainelX+10+coluna*165);
   ObjectSetInteger(0,nome,OBJPROP_YDISTANCE,PainelY+8+linha*17);
   ObjectSetInteger(0,nome,OBJPROP_COLOR,cor);
   ObjectSetString(0,nome,OBJPROP_TEXT,s);
}

string Reais(const double v) { return "R$ "+DoubleToString(v,2); }
string Taxa(const int a, const int t) { return IntegerToString(a)+"/"+IntegerToString(t)+(t>0?" ("+DoubleToString(100.0*a/t,1)+"%)":""); }

void AtualizarPainel()
{
   if(!visualDisponivel || !ExibirPainel) return;
   string fundo=prefixo+"FUNDO";
   if(ObjectFind(0,fundo)<0)
   {
      ObjectCreate(0,fundo,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,fundo,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,fundo,OBJPROP_BGCOLOR,C'20,28,36');
      ObjectSetInteger(0,fundo,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,fundo,OBJPROP_COLOR,C'60,90,120');
      ObjectSetInteger(0,fundo,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,fundo,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,fundo,OBJPROP_XDISTANCE,PainelX);
   ObjectSetInteger(0,fundo,OBJPROP_YDISTANCE,PainelY);
   ObjectSetInteger(0,fundo,OBJPROP_XSIZE,340);
   ObjectSetInteger(0,fundo,OBJPROP_YSIZE,13*17+14);

   ulong tk; double vol, luc;
   int pos=PosicaoDoEA(tk,vol,luc);
   if(pos!=0) rebaixamentoPosicao=MathMin(rebaixamentoPosicao,luc); else rebaixamentoPosicao=0.0;
   long segundosVela=PeriodSeconds(PeriodoDosSinais)-(long)(TimeCurrent()-iTime(_Symbol,PeriodoDosSinais,0));
   if(segundosVela<0) segundosVela=0;
   color cinza=C'170,180,190', branco=clrWhite;

   Texto(0,0,"EA11 HILO SCALPER",branco);
   Texto(0,1,_Symbol+" "+StringSubstr(EnumToString(PeriodoDosSinais),7),cinza);
   Texto(1,0,"Cotacao: "+DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits),cinza);
   Texto(1,1,"Horario: "+TimeToString(TimeCurrent(),TIME_SECONDS),cinza);
   Texto(2,0,"HiLo: "+(tendenciaAtual>0?"ALTA":tendenciaAtual<0?"BAIXA":"-")+" "+(linhaAtual>0?DoubleToString(linhaAtual,_Digits):""),
         tendenciaAtual>0?CorCompra:tendenciaAtual<0?CorVenda:cinza);
   Texto(2,1,StringFormat("Vela: %d:%02d",(int)(segundosVela/60),(int)(segundosVela%60)),cinza);
   Texto(3,0,"Posicao: "+(pos>0?"COMPRADO":pos<0?"VENDIDO":"SEM POSICAO"),pos>0?CorCompra:pos<0?CorVenda:cinza);
   Texto(3,1,"Volume: "+DoubleToString(vol,2),cinza);
   Texto(4,0,"Lucro: "+Reais(luc),luc>=0?clrMediumSeaGreen:clrTomato);
   Texto(4,1,"Rebaixamento: "+Reais(rebaixamentoPosicao),clrTomato);
   Texto(5,0,"DIARIO",branco);                          Texto(5,1," ",cinza);
   Texto(6,0,"Ganho: "+Reais(ganhoDia),clrMediumSeaGreen); Texto(6,1,"Perda: "+Reais(perdaDia),clrTomato);
   double rd=ganhoDia-perdaDia;
   Texto(7,0,"Resultado: "+Reais(rd),rd>=0?clrMediumSeaGreen:clrTomato);
   Texto(7,1,"Acerto: "+Taxa(acertosDia,totalDia),cinza);
   Texto(8,0,"MENSAL",branco);                          Texto(8,1," ",cinza);
   Texto(9,0,"Ganho: "+Reais(ganhoMes),clrMediumSeaGreen); Texto(9,1,"Perda: "+Reais(perdaMes),clrTomato);
   double rm=ganhoMes-perdaMes;
   Texto(10,0,"Resultado: "+Reais(rm),rm>=0?clrMediumSeaGreen:clrTomato);
   Texto(10,1,"Acerto: "+Taxa(acertosMes,totalMes),cinza);
   Texto(11,0,StringFormat("Alvo %d / Stop %d pts | %.0f contr.",AlvoPontos,StopPontos,Contratos),cinza);
   Texto(11,1," ",cinza);
   Texto(12,0,"Estado: "+estado,clrKhaki);              Texto(12,1," ",cinza);
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
bool Entrar(const int lado)
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0 || tick.ask<=0) { estado="Sem cotacao"; return false; }
   if(SpreadMaximoPontos>0 && (tick.ask-tick.bid)/_Point>SpreadMaximoPontos) { estado="Spread alto"; return false; }
   double passo=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); if(passo<=0) passo=_Point;
   double minStop=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point+passo;
   double sl,tp;
   if(lado>0)
   {
      sl=PrecoAjustado(MathMin(tick.ask-StopPontos*_Point,tick.bid-minStop));
      tp=PrecoAjustado(MathMax(tick.ask+AlvoPontos*_Point,tick.bid+minStop));
   }
   else
   {
      sl=PrecoAjustado(MathMax(tick.bid+StopPontos*_Point,tick.ask+minStop));
      tp=PrecoAjustado(MathMin(tick.bid-AlvoPontos*_Point,tick.ask-minStop));
   }
   double vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN), vstep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double vol=MathMax(vmin,MathFloor(Contratos/vstep+1e-9)*vstep);
   double margem=0;
   ENUM_ORDER_TYPE tipo=(lado>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   if(!OrderCalcMargin(tipo,_Symbol,vol,lado>0?tick.ask:tick.bid,margem) || margem>AccountInfoDouble(ACCOUNT_MARGIN_FREE))
   { estado="Margem insuficiente"; return false; }
   bool ok=(lado>0?negociador.Buy(vol,_Symbol,0,sl,tp,"EA11 HiLo C"):negociador.Sell(vol,_Symbol,0,sl,tp,"EA11 HiLo V"));
   uint rc=negociador.ResultRetcode();
   if(!ok || (rc!=TRADE_RETCODE_DONE && rc!=TRADE_RETCODE_DONE_PARTIAL))
   {
      estado="Ordem recusada: "+negociador.ResultRetcodeDescription();
      PrintFormat("ENTRADA RECUSADA: %s",negociador.ResultRetcodeDescription());
      return false;
   }
   historicoSujo=true;
   rebaixamentoPosicao=0.0;
   estado=(lado>0?"Comprado na virada do HiLo":"Vendido na virada do HiLo");
   if(MostrarDiagnosticos) PrintFormat("%s: %.0f contratos, SL %s, TP %s",estado,vol,DoubleToString(sl,_Digits),DoubleToString(tp,_Digits));
   return true;
}

//+------------------------------------------------------------------+
int OnInit()
{
   minInicio=ConverterHorario(HoraInicio); minFim=ConverterHorario(HoraFim); minZeragem=ConverterHorario(HoraZeragem);
   if(minInicio==-2 || minFim==-2 || minZeragem==-2) { Print("Horario invalido: use HH:MM ou 0."); return INIT_PARAMETERS_INCORRECT; }
   if(NumeroMagico<=0 || Contratos<=0 || AlvoPontos<=0 || StopPontos<=0 || PeriodoHiLo<1 ||
      GanhoMaximoDia<0 || PerdaMaximaDia<0 || OperacoesMaximasDia<0 || SpreadMaximoPontos<0 || BarrasDesenhadas<10)
   { Print("Parametros invalidos."); return INIT_PARAMETERS_INCORRECT; }

   hMaxima=iMA(_Symbol,PeriodoDosSinais,PeriodoHiLo,0,MetodoHiLo,PRICE_HIGH);
   hMinima=iMA(_Symbol,PeriodoDosSinais,PeriodoHiLo,0,MetodoHiLo,PRICE_LOW);
   if(hMaxima==INVALID_HANDLE || hMinima==INVALID_HANDLE) { Print("Falha ao criar as medias do HiLo."); return INIT_FAILED; }

   negociador.SetExpertMagicNumber((ulong)NumeroMagico);
   negociador.SetDeviationInPoints((ulong)DesvioMaximoPontos);
   negociador.SetTypeFillingBySymbol(_Symbol);
   negociador.LogLevel(LOG_LEVEL_ERRORS);

   prefixo="EA11_"+IntegerToString(NumeroMagico)+"_";
   visualDisponivel=(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE));
   ultimaBarra=iTime(_Symbol,PeriodoDosSinais,0);   // nao entra no meio da barra atual
   if(visualDisponivel)
   {
      ChartSetInteger(0,CHART_FOREGROUND,false);
      EventSetTimer(1);
      DesenharHistoricoHiLo();
      estado=(AmbientePermitido()?"Aguardando virada do HiLo":"Bloqueado neste ambiente (veja grupo 01)");
      AtualizarHistorico();
      AtualizarPainel();
   }
   PrintFormat("EA11 HiLo iniciado: %s %s, HiLo %d %s, alvo %d, stop %d, %.0f contratos",
               _Symbol,EnumToString(PeriodoDosSinais),PeriodoHiLo,EnumToString(MetodoHiLo),AlvoPontos,StopPontos,Contratos);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int motivo)
{
   if(visualDisponivel) { EventKillTimer(); LimparObjetos(); ChartRedraw(0); }
   if(hMaxima!=INVALID_HANDLE) IndicatorRelease(hMaxima);
   if(hMinima!=INVALID_HANDLE) IndicatorRelease(hMinima);
}

void OnTimer() { AtualizarHistorico(); AtualizarPainel(); }

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
void OnTick()
{
   AtualizarHistorico();
   if(!AmbientePermitido()) { estado="Bloqueado neste ambiente (veja grupo 01)"; return; }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED)) { estado="Algotrading desligado"; return; }

   ulong tk; double vol, luc;
   int pos=PosicaoDoEA(tk,vol,luc);
   if(pos!=0) rebaixamentoPosicao=MathMin(rebaixamentoPosicao,luc);

   // Zeragem no fim do dia.
   if(HorarioDeZeragem())
   {
      if(pos!=0) FecharPosicao("horario de zeragem");
      estado="Horario de zeragem";
      return;
   }

   // Somente uma vez por barra nova do tempo grafico do HiLo.
   datetime barra=iTime(_Symbol,PeriodoDosSinais,0);
   if(barra==0 || barra==ultimaBarra) return;

   int tend[]; double lin[]; datetime tm[];
   if(!CalcularHiLo(MathMax(PeriodoHiLo*5,50),tend,lin,tm)) { estado="Aguardando dados do HiLo"; return; }
   ultimaBarra=barra;
   int n=ArraySize(tend);
   int agora=tend[n-1], antes=tend[n-2];
   bool virada=(agora!=0 && antes!=0 && agora!=antes);
   tendenciaAtual=agora; linhaAtual=lin[n-1];
   DesenharBarra(tm[n-2],lin[n-2],tm[n-1],lin[n-1],agora,virada);
   if(!virada) return;

   if(MostrarDiagnosticos) PrintFormat("Virada do HiLo para %s em %s",agora>0?"ALTA":"BAIXA",TimeToString(tm[n-1]));

   // Saida opcional na virada contraria.
   if(pos!=0 && pos!=agora && SairNaViradaContraria) { FecharPosicao("virada contraria do HiLo"); return; }
   if(pos!=0 || ExistePosicaoNoAtivo()) { estado="Virada ignorada: ja posicionado"; return; }

   double rd=ganhoDia-perdaDia;
   if(GanhoMaximoDia>0 && rd>=GanhoMaximoDia) { estado="Meta diaria atingida"; return; }
   if(PerdaMaximaDia>0 && rd<=-PerdaMaximaDia) { estado="Perda maxima diaria atingida"; return; }
   if(OperacoesMaximasDia>0 && entradasDia>=OperacoesMaximasDia) { estado="Limite de entradas do dia"; return; }
   if(!DentroDoHorario()) { estado="Virada fora do horario"; return; }
   if(agora>0 && !PermitirCompras) { estado="Compras desativadas"; return; }
   if(agora<0 && !PermitirVendas) { estado="Vendas desativadas"; return; }

   Entrar(agora);
}
//+------------------------------------------------------------------+
