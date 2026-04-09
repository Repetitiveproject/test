/*********************************************
 * OPL 12.6.1.0 Model
 * Modified: 修复 endBeforeStart 顶层约束错误
 *********************************************/
using CP;

/*parameters*/
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

/*decision variables*/
dvar interval S[i in 1..N][j in 1..U];
dvar interval alt1[p in Alternatives1] optional;
dvar interval crew[i in 1..N][k in 1..MaxCrew] optional;    
dvar int+ t1;

// 实际雇佣的工作队数量，范围是 1 到 K[i]
dvar int actualCrewCount[i in 1..N] in 1..K[i];

// 资源累积函数
cumulFunction resourceUsage[r in 1..R] = 
    sum(i in 1..N, j in 1..U) 
        pulse(S[i][j], resourceDemand[i][r]);

/*objective*/
minimize t1;

/*constraints*/
subject to{
  
    // ============ 每个单元工期必须等于d[i][j] ============
    forall(i in 1..N, j in 1..U)
        lengthOf(S[i][j]) == d[i][j];
    
    // 原有的总工期约束
    forall(i in 1..N)
        sum(j in 1..U) lengthOf(S[i][j]) == TotalDuration[i];
    
    // alternative约束
    forall(i in 1..N, j in 1..U)
        alternative(S[i][j], all(p in Alternatives1: p.actID==i && p.unitID==j) alt1[p]);
      
    // ============ 动态分配工作队逻辑 ============
    // 修复：避免直接对 decision variable 取模，改为遍历可能的 k 值
    forall(p in Alternatives1) {
        forall(k in 1..K[p.actID]) {
            // 如果活动使用了 k 个工作队，则根据数学规则判断该 alternative 是否存在
            (actualCrewCount[p.actID] == k) => 
                (presenceOf(alt1[p]) == (p.crewID == (p.unitID - 1) % k + 1));
        }
    }
       
    // ============ crew的span和连续性约束 ============
    forall(i in 1..N, k in 1..MaxCrew) {
        span(crew[i][k], all(p in Alternatives1: p.actID==i && p.crewID==k) alt1[p]); 
        noOverlap(all(p in Alternatives1: p.actID==i && p.crewID==k) alt1[p]);
        sizeOf(crew[i][k]) == sum(p in Alternatives1: p.actID==i && p.crewID==k) 
                              (lengthOf(alt1[p]) * presenceOf(alt1[p]));
    } 
    
    // ============ 动态顺序约束 ============
    // 逻辑：如果选择了 k 个队，则单元 j 必须在单元 j+k 之前完成
    forall(i in 1..N) {
        forall(j in 1..U) {
            forall(k in 1..K[i]) {
                // 如果 j+k 还在范围内，且选择了 k 个队
                // 使用 endOf(...) <= startOf(...) 替代 endBeforeStart(...)
                if (j + k <= U) {
                     (actualCrewCount[i] == k) => (endOf(S[i][j]) <= startOf(S[i][j+k]));
                }
            }
        }
    }
    
    // ============ 复杂网络优先关系约束 ============
    forall(i in 1..N, pre in predecessors[i], j in 1..U)
        endBeforeStart(S[pre][j], S[i][j]);
      
    // ============ 最终时间约束 ============
    forall(i in 1..N, j in 1..U)
        endOf(S[i][j]) <= t1;
      
    // ============ crew的presence约束 ============
    // 只有编号 <= actualCrewCount[i] 的工作队是激活的
    forall(i in 1..N, k in 1..MaxCrew)
        presenceOf(crew[i][k]) == (k <= actualCrewCount[i]);
    
    // 资源约束
    forall(r in 1..R)
        resourceUsage[r] <= resourceCapacity[r];
    
    // ============ 累积完工比例约束 ============
    forall(i in 1..N, pre in predecessors[i]) {
        forall(j in 1..U) { 
            min(o in 1..U) startOf(S[i][o]) >= min(o in 1..U) startOf(S[pre][o]) + TotalDuration[pre]/(U*2);
           
            (TotalDuration[i] - sum(o in 1..U) maxl(0, endOf(S[i][o]) - endOf(S[i][j]))) * TotalDuration[pre]
            <= (TotalDuration[pre] - sum(o in 1..U) maxl(0, endOf(S[pre][o]) - endOf(S[i][j]))) * TotalDuration[i];        
           
            (TotalDuration[i] - sum(o in 1..U) maxl(0, endOf(S[i][o]) - startOf(S[i][j]))) * TotalDuration[pre]
            <= (TotalDuration[pre] - sum(o in 1..U) maxl(0, endOf(S[pre][o]) - startOf(S[i][j]))) * TotalDuration[i];        
        }  
    }      
}