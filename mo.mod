/*********************************************
 * OPL 12.6.1.0 Model
 * Modified: 采用前继活动判断累积完工量 + 强制顺序破除对称性
 *********************************************/
using CP;

/* parameters */
int N=...;                                    
int U=...;                                    
int R=...;                                    
int d[1..N][1..U]=...;                        
int K[1..N]=...;                              
int MaxCrew=...;                                
int resourceCapacity[1..R]=...;               
int resourceDemand[1..N][1..R]=...;          
{int} predecessors[1..N]=...;                

int TotalDuration[i in 1..N] = sum(j in 1..U) d[i][j];

tuple Alternative1{
  int actID;
  int unitID;
  int crewID;
};
{Alternative1} Alternatives1=...;

/* decision variables */
dvar interval S[i in 1..N][j in 1..U];
dvar interval alt1[p in Alternatives1] optional;
dvar int+ t1;

// ==========================================
// FCF 策略连续流映射所需的高效辅助区间变量
// ==========================================
dvar interval Act[1..N];                        // 宏观活动总区间
dvar interval W_end[1..N][1..U];                // 前缀时间窗：从 0时刻 到 单元j结束

// 资源累积函数
cumulFunction resourceUsage[r in 1..R] = 
    sum(i in 1..N, j in 1..U) 
        pulse(S[i][j], resourceDemand[i][r]);

/* objective */
minimize t1;

/* constraints */
subject to{

    // 1. 绑定宏观活动区间：Act囊括其所有子单元
    forall(i in 1..N)
        span(Act[i], all(j in 1..U) S[i][j]);

    // 2. 绑定前缀时间窗变量 (清理了多余的 W_start)
    forall(i in 1..N, j in 1..U) {
        startOf(W_end[i][j]) == 0;
        endAtEnd(W_end[i][j], S[i][j]);
    }

    // 工作量拆分逻辑约束
    forall(i in 1..N)
        sum(j in 1..U) lengthOf(S[i][j]) == TotalDuration[i];
        
    forall(i in 1..N, j in 1..U)
        lengthOf(S[i][j]) >= TotalDuration[i]/(U*2);
        
    // alternative 约束
    forall(i in 1..N, j in 1..U)
        alternative(S[i][j], all(p in Alternatives1: p.actID==i && p.unitID==j) alt1[p]);
     
    // crew 的 span 和 noOverlap 约束
    forall(i in 1..N, k in 1..MaxCrew) {
        noOverlap(all(p in Alternatives1: p.actID==i && p.crewID==k) alt1[p]);
    } 
     
    // 最终时间约束
    forall(i in 1..N, j in 1..U)
        endOf(S[i][j]) <= t1;
    
    // 资源约束
    forall(r in 1..R)
        resourceUsage[r] <= resourceCapacity[r]*4;
    
    // ==========================================
    // 累积完工比例约束 - 采用前继活动 (pre) 作为检查锚点
    // ==========================================
    forall(i in 1..N, pre in predecessors[i]) {
        
        // 物理缓冲时间限制：利用宏观活动的 startOf 约束首单元
        startOf(Act[i]) >= startOf(Act[pre]) + TotalDuration[pre]/(U*2);
        
        forall(j in 1..U) {       
            
            // 在【前继活动 pre】的单元 j 结束时刻：
            // 确保紧后活动 i 的已完工比例 <= 紧前活动 pre 的已完工比例
            (sum(o in 1..U) overlapLength(S[i][o], W_end[pre][j])) * TotalDuration[pre]
            <= (sum(o in 1..U) overlapLength(S[pre][o], W_end[pre][j])) * TotalDuration[i];        
        }  
    }      
}

execute {
    writeln("Optimization completed");
    writeln("Project makespan: ", t1);
    for(var i=1; i<=N; i++) {
        writeln("Activity ", i, " (", K[i], " crews):");
        for(var j=1; j<=U; j++) {
            writeln("  Unit ", j, ": start=", S[i][j].start, ", end=", S[i][j].end);
        }
    }
}