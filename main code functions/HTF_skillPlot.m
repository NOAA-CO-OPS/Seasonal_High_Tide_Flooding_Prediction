function HTF_skillPlot(stationNum,leadTime,startStr,endStr)

%This function plots the results of the HTF prediction skill assessment for
% a particular station, leadtime and start and end date

% stationNum = station number as a string, eg: '1612340'
% leadTime = number of months lead you wish to plot from 1 - 12 eg: 2
% startStr = The starting date you wish to plot in a date str eg: '20200101'
% endStr = The ending date you wish to plot in a date str eg: '20201231'

%Load the data
load([stationNum,'_skill']);

startDate=datetime(startStr,'InputFormat','yyyyMMdd');
endDate=datetime(endStr,'InputFormat','yyyyMMdd');
thresh = skillOut.minorThresh;

%find the hourly indices we want to plot
ind=find(skillOut.dailyProbTime >= startDate & skillOut.dailyProbTime <= endDate);
yn=find(skillOut.ynObs(ind) == 1);
indyn=ind(yn);

%Find the hourly indices where it floods, but the predicted likelihood is
%under the 5% threshold
ynMissed=find(skillOut.dailyProb(leadTime,indyn) < 0.05);
indynMissed=indyn(ynMissed);

%Find the hourly indices where it floods, and it was accurately predicted
%(the prediction > = the 5% flood threshold)
ynCorrect=find(skillOut.dailyProb(leadTime,indyn) >= 0.05);
indynCorrect=indyn(ynCorrect);

%Do math on the number of flood days in time period and how many were
%predicted correctly
totalFloodDays=length(indyn);
floodDaysPredicted=length(indynCorrect);


%% Plot the data
ax1=subplot(2,1,1);
p1=plot(skillOut.dailyProbTime(ind),skillOut.dailyObs(ind),'LineWidth',2);
hold on
p2=plot(skillOut.dailyProbTime(ind),skillOut.dailyTidePred(ind),'LineWidth',2);
plot([skillOut.dailyProbTime(ind(1)) skillOut.dailyProbTime(ind(end))],[thresh thresh])
%Plot the correctly predicted days
p3=plot(skillOut.dailyProbTime(indynCorrect),skillOut.dailyObs(indynCorrect),'ro','MarkerFaceColor','r');
%Plot the days we missed
p4=plot(skillOut.dailyProbTime(indynMissed),skillOut.dailyObs(indynMissed),'ko','MarkerFaceColor','k');

title(['Station ', stationNum]);
subtitle(['From ',datestr(startDate,'mmm dd, yyyy '), 'to ', datestr(endDate,'mmm dd, yyyy')]);
ylabel('Water Level MHHW (m)')
%ax1.XTick=[datetime(yearPlot,1,1) datetime(yearPlot,3,1) datetime(yearPlot,5,1) datetime(yearPlot,7,1) datetime(yearPlot,9,1) datetime(yearPlot,11,1)];
ax1.XTickLabel={};
ax1pos=get(ax1,'Position');
posWidth=ax1pos(4);

legend([p1 p2 p3 p4],{'Observed', 'Tide Prediction','Predicted Floods','Missed Floods'});

ax2=subplot(2,1,2);
plot(skillOut.dailyProbTime(ind),skillOut.dailyProb(leadTime,ind),'LineWidth',2)
hold on
plot([skillOut.dailyProbTime(ind(1)) skillOut.dailyProbTime(ind(end))],[0.05 0.05])
%plot the correctly predicted days
plot(skillOut.dailyProbTime(indynCorrect),skillOut.dailyProb(leadTime,indynCorrect),'ro','MarkerFaceColor','r')
%plot the days we missed the prediction
plot(skillOut.dailyProbTime(indynMissed),skillOut.dailyProb(leadTime,indynMissed),'ko','MarkerFaceColor','k')

ylabel('Flooding Likelihood')
ylim([0 1])
%ax2.XTickLabel=ax2.XTickLabel; 
ax2.YTick=[0.2 0.4 0.6 0.8 1];

ax2pos=get(ax2,'Position');
ax2pos(3)=ax1pos(3);
ax2pos(4)=ax1pos(4);
ax2pos(2)=ax2pos(2)+.05;
ax2.Position=ax2pos;

linkaxes([ax1,ax2],'x');
fontsize(gcf,14,"points")




end