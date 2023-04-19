function [out]=reliability(obs,forecast)

%This function calculates the reliabity and resolution of a probabilistic
%forecast and plots the results

%obs is the observed 0 or 1 values (y or n event)

%forecast is the forecasted likelihood from 0 to 1

%What are the bins
bins=[0:.1:1];
n=length(bins)-1;

rel=nan(n,1);
res=nan(n,1);
xVal=nan(n,1);

for i = 1:n
    if i < n
        ind=find(forecast >= bins(i) & forecast < bins(i+1));
    else
        ind=find(forecast >= bins(i) & forecast <= bins(i+1));
    end
    res(i)=length(ind)./length(forecast);
    rel(i)=nanmean(obs(ind));
    xVal(i)=nanmean(forecast(ind));
end

% figure
 %for plotting
 xVal2=0.05:.1:.95;
% 
% ax1=subplot(2,1,1);
% plot(xVal,rel,'bo-')
% hold on
% plot([0 1],[0 1],'k--')
% xlim([0 1]);
% 
% ax2=subplot(2,1,2);
% bar(xVal2,res);
% xlim([0 1]);
% 
% ax1pos=get(ax1,'Position');
% ax1pos(3)=ax1pos(3).*.6;
% ax1pos(4)=ax1pos(3);
% ax1pos(2)=.4;
% ax1.Position=ax1pos;
% ax1.XTickLabel={};
% ylabel(ax1,'Observed Frequency');
% title(ax1,'Forecast Reliability');
% 
% ax2pos=get(ax2,'Position');
% ax2pos(3)=ax1pos(3);
% ax2pos(4)=ax1pos(4).*.4;
% ax2pos(2)=ax1pos(2)-ax2pos(4)-ax2pos(4).*.22;
% ax2.Position=ax2pos;
% xlabel(ax2,'Forecasted Probability');
% ylabel(ax2,'Forecast Frequency');
% title(ax2,'Forecast Resolution');

%Adding a figure comparing the histograms of the predicted to observed
%figure
%bar(xVal2,cat(2,xVal,rel))


out.xVal=xVal;
out.xVal2=xVal2;
out.rel=rel;
out.res=res;
    
    