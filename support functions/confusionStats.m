function confusion = confusionStats(ynObs,pred,thresh)

%This function takes [ynObs] a observed y/n (1 or 0) time series and [pred] a predicted
%probability time series (0 to 1) along with [thresh] the desired y/n
%threshold to apply to the predicted time series to calculate a confusion
%matrix and associated statistics
n=length(pred);

ynPred=zeros(n,1);

for i =1:n
    if pred(i)>=thresh
        ynPred(i)=1;
    else
        continue
    end
end

C = confusionmat(ynObs,ynPred);

%need to add something to account for cases when no positive or predicted
%positive cases occur
if isscalar(C)
    C=zeros(2,2);
    C(1)=n;
end

confusion.C=C;
confusion.trueNeg=C(1);
confusion.truePos=C(4);
confusion.falseNeg=C(2);
confusion.falsePos=C(3);

%Accuracy =total predicted correct / total number of predictions
confusion.accuracy=(confusion.truePos+confusion.trueNeg)/(sum(C,'all'));

%Precision = True Positive (correct) / All predicted positive
allPredPos=(confusion.truePos+confusion.falsePos);
if allPredPos == 0
    confusion.precision=NaN;
else
    confusion.precision=confusion.truePos/allPredPos;
end

%recall or sensitivity = True positive / All observe positive
allObsPos=(confusion.truePos+confusion.falseNeg);
if allObsPos == 0
    confusion.recall=NaN;
else
    confusion.recall=confusion.truePos/allObsPos;
end

%False Alarm = False Positive / All observe negative
allObsNeg=(confusion.trueNeg+confusion.falsePos);
if allObsNeg == 0
    confusion.falseAlarm=NaN;
else
    confusion.falseAlarm=confusion.falsePos/allObsNeg;
end

%F1 score - Measure of accuracy, the harmonic mean of precision and recall
confusion.F1=2*((confusion.precision*confusion.recall)/(confusion.precision+confusion.recall));



%confusionchart(ynObs,ynPred);

