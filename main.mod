main {
  // ==================== 配置区域 ====================
  // 【只需要修改这里】设置要跑的数据实例数量
  var numInstances = 480; 
  // ================================================

  // 1. 自动生成实例文件名列表 (instance1.dat, instance2.dat, ...)
  var instanceFiles = new Array();
  for(var k = 1; k <= numInstances; k++) {
    instanceFiles[k-1] = "instance" + k + ".dat";
  }

  // 2. 定义你要跑的三个模型文件 (修改为: mo -> mo4 -> mo2)
  var modelFiles = new Array();
  modelFiles[0] = "mo.mod";
  modelFiles[1] = "mo4.mod";
  modelFiles[2] = "mo2.mod";

  // 3. 定义策略名称 (对应上面的模型顺序)
  var modelNames = new Array();
  modelNames[0] = "FSF策略";                          // mo
  modelNames[1] = "split-overlap策略";                // mo4
  modelNames[2] = "soft logic-interruption-crew策略"; // mo2

  // ==================== 统计变量初始化 ====================
  var totalObjectives = new Array(); // 存储每个策略的目标值总和
  var successCounts = new Array();   // 存储每个策略的成功求解次数
  
  // 初始化数组 (自动根据modelFiles长度遍历，无需手动修改)
  for(var m = 0; m < modelFiles.length; m++) {
      totalObjectives[m] = 0.0;
      successCounts[m] = 0;
  }
  // =======================================================

  // 准备输出文件
  var solFileName = "result_summary.txt";
  var solFile = new IloOplOutputFile(solFileName);
  solFile.writeln("Instance\tStrategy\tStatus\tObjective\tTime(s)");
  solFile.close();

  writeln("准备处理 " + numInstances + " 个数据文件...");

  // ==================== 双层循环开始 ====================
  
  // 外层循环：遍历所有生成的数据文件
  for(var i = 0; i < instanceFiles.length; i++) {
    var currentDatFile = instanceFiles[i];
    writeln("\n###########################################################");
    writeln("正在处理 (" + (i+1) + "/" + numInstances + "): " + currentDatFile);

    // 内层循环：遍历模型数组
    for(var m = 0; m < modelFiles.length; m++) {
      var currentModFile = modelFiles[m];
      var currentStrategy = modelNames[m];
      
      var source = new IloOplModelSource(currentModFile);
      var def = new IloOplModelDefinition(source);
      var cp = new IloCP();
      var opl = new IloOplModel(def, cp);
      var data = new IloOplDataSource(currentDatFile); 
      opl.addDataSource(data);
      opl.generate();
      
      // 设置求解参数
      cp.param.timelimit = 60;
      cp.param.logperiod = 10000;
      
      writeln("--- 开始求解: " + currentModFile + " [" + currentStrategy + "] ---");

      var outputLine = currentDatFile + "\t" + currentStrategy + "\t";
      
      // 求解
      if (cp.solve()) {
        var objVal = opl.t1; 
        
        // 【统计累加】
        totalObjectives[m] = totalObjectives[m] + objVal;
        successCounts[m] = successCounts[m] + 1;
        
        writeln("    >>> [" + currentStrategy + "] 成功! 目标值: " + objVal);
        outputLine = outputLine + "Success\t" + objVal + "\t" + cp.info.TotalTime;
      } else {
        writeln("    >>> [" + currentStrategy + "] 失败或超时");
        outputLine = outputLine + "Fail\t-\t" + cp.info.TotalTime;
      }

      // 写入单次结果
      solFile = new IloOplOutputFile(solFileName, true);
      solFile.writeln(outputLine);
      solFile.close();

      opl.end();
      data.end();
      def.end();
      source.end();
      cp.end(); 
    }
  }
  
  // ==================== 计算并输出平均值 ====================
  writeln("\n==================================================");
  writeln("全部处理完成。正在统计平均值...");
  
  solFile = new IloOplOutputFile(solFileName, true);
  solFile.writeln();
  solFile.writeln("========== 平均值统计 ==========");
  solFile.writeln("Strategy\tAvgObjective\tSuccessRate");
  
  for(var m = 0; m < modelFiles.length; m++) {
      var avgObj = 0;
      if (successCounts[m] > 0) {
          avgObj = totalObjectives[m] / successCounts[m];
      }
      
      var msg = "策略 [" + modelNames[m] + "] (" + modelFiles[m] + "): ";
      msg = msg + "平均目标值 = " + avgObj;
      msg = msg + ", 成功次数 = " + successCounts[m] + "/" + numInstances;
      
      writeln(msg);
      solFile.writeln(modelNames[m] + "\t" + avgObj + "\t" + successCounts[m] + "/" + numInstances);
  }
  
  solFile.close();
  writeln("结果已保存至: " + solFileName);
}