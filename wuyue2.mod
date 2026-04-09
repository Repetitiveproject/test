using CP;

/*参数*/
int N=...;                                    
int U=...;                                    
int R=...;                                    
int d[1..N][1..U]=...;                        
int resourceCapacity[1..R]=...;               
int resourceDemand[1..N][1..R]=...;          
{int} predecessors[1..N]=...;                

int TotalDuration[i in 1..N] = sum(j in 1..U) d[i][j];

/*决策变量*/
dvar interval S[i in 1..N][j in 1..U];
dvar int+ t1;
dvar interval  ActivitySpan[i in 1..N];
// 资源累积函数
cumulFunction resourceUsage[r in 1..R] = 
    sum(i in 1..N, j in 1..U) 
        pulse(S[i][j], resourceDemand[i][r]);



/*目标函数*/
minimize t1;

/*约束*/
subject to{
    // 1. 总工期约束
    forall(i in 1..N)
        sum(j in 1..U) lengthOf(S[i][j]) == TotalDuration[i];
    
    // 2. 最小工期约束（防止过度分割）
    forall(i in 1..N, j in 1..U)
        lengthOf(S[i][j]) >= TotalDuration[i]/(U*2);
    
    // 3. **核心简化**：同一活动的不同单元不能重叠（因为只有一个工作队）
    forall(i in 1..N)
        noOverlap(all(j in 1..U) S[i][j]);
    
    // 5. 最终时间约束
    forall(i in 1..N, j in 1..U)
        endOf(S[i][j]) <= t1;
    
    // 6. 资源约束
    forall(r in 1..R)
        resourceUsage[r] <= resourceCapacity[r];
    
    // 7. 累积完工比例约束
    forall(i in 1..N, pre in predecessors[i]) {
        forall(j in 1..U) { 
//        sum(o in 1..U) maxl(0, endOf(S[pre][o]) - startOf(S[i][j])) <= 0.8 * TotalDuration[pre]; 
        
        min(o in 1..U) startOf(S[i][j]) >=  min(o in 1..U)  startOf(S[pre][o]) + TotalDuration[pre]/(U*2);
            // 在单元j结束时刻：
         (TotalDuration[i] - sum(o in 1..U) maxl(0, endOf(S[i][o]) - endOf(S[i][j])))  * TotalDuration[pre]
<=          (TotalDuration[pre] - sum(o in 1..U) maxl(0,endOf(S[pre][o]) - endOf(S[i][j])))  * TotalDuration[i];        
       (TotalDuration[i] - sum(o in 1..U) maxl(0, endOf(S[i][o]) - startOf(S[i][j])))  * TotalDuration[pre]
<=          (TotalDuration[pre] - sum(o in 1..U) maxl(0,endOf(S[pre][o]) - startOf(S[i][j])))  * TotalDuration[i];        
        }  
}


            // 4. ✅ 新增：span约束确保所有单元在ActivitySpan范围内
    forall(i in 1..N)
        span(ActivitySpan[i], all(j in 1..U) S[i][j]);
    
    // 5. ✅ 新增：关键约束 - ActivitySpan的长度必须等于总工期（无空闲）
    forall(i in 1..N)
        sizeOf(ActivitySpan[i]) == TotalDuration[i];
        
        forall(i in 1..N, j in 1..U-1)
        endBeforeStart(S[i][j], S[i][j+1]);   
         

}