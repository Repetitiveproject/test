/*********************************************
 * OPL 12.6.1.0 Model
 * Modified: 添加单元工期固定约束和工作队连续性约束
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

// 资源累积函数
cumulFunction resourceUsage[r in 1..R] = 
    sum(i in 1..N, j in 1..U) 
        pulse(S[i][j], resourceDemand[i][r]);

/*objective*/
minimize t1;

/*constraints*/
subject to{
  
    // ============ 新增：每个单元工期必须等于d[i][j] ============
    forall(i in 1..N, j in 1..U)
        lengthOf(S[i][j]) == d[i][j];
    
    // 原有的总工期约束（已被上面的约束隐含满足）
    forall(i in 1..N)
        sum(j in 1..U) lengthOf(S[i][j]) == TotalDuration[i];
    
    // alternative约束
    forall(i in 1..N, j in 1..U)
        alternative(S[i][j], all(p in Alternatives1: p.actID==i && p.unitID==j) alt1[p]);
     
    // ============ 修改：crew的span和连续性约束 ============
    forall(i in 1..N, k in 1..MaxCrew) {
        // span约束保证crew[i][k]覆盖所有被选中的alt1任务
        span(crew[i][k], all(p in Alternatives1: p.actID==i && p.crewID==k) alt1[p]); 
        
        // noOverlap约束保证同一个工作队不同时执行多个单元
        noOverlap(all(p in Alternatives1: p.actID==i && p.crewID==k) alt1[p]);
        
        // ============ 新增：工作队连续性约束 ============
        // crew[i][k]的总工期必须等于其执行的所有单元工期之和
        // 这确保了工作队在其工作期间没有空闲时间
//        sizeOf(crew[i][k]) == sum(p in Alternatives1: p.actID==i && p.crewID==k) 
//                              (lengthOf(alt1[p]) * presenceOf(alt1[p]));
    } 
    
    // 复杂网络优先关系约束
    forall(i in 1..N, pre in predecessors[i], j in 1..U)
        endBeforeStart(S[pre][j], S[i][j]);
     
    // 最终时间约束
    forall(i in 1..N, j in 1..U)
        endOf(S[i][j]) <= t1;
      
    // crew的presence约束
    forall(i in 1..N, k in 2..MaxCrew)
        presenceOf(crew[i][k-1]) >= presenceOf(crew[i][k]);
    
    forall(i in 1..N, k in (K[i]+1)..MaxCrew)
        presenceOf(crew[i][k]) == 0;
    
    // 资源约束
    forall(r in 1..R)
        resourceUsage[r] <= resourceCapacity[r]*4;
        
}

execute {
    writeln("Optimization completed");
    writeln("Project makespan: ", t1);
    for(var i=1; i<=N; i++) {
        writeln("Activity ", i, " (", K[i], " crews):");
        for(var j=1; j<=U; j++) {
            writeln("  Unit ", j, ": start=", S[i][j].start, 
                    ", end=", S[i][j].end, 
                    ", duration=", S[i][j].end - S[i][j].start);
        }
        for(var k=1; k<=K[i]; k++) {
            if(crew[i][k].present) {
                writeln("  Crew ", k, ": start=", crew[i][k].start, 
                        ", end=", crew[i][k].end,
                        ", size=", crew[i][k].size);
            }
        }
    }
}