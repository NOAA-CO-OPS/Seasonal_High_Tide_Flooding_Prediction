function [timeInDatetime]=tc(timeInDatenum)

%A simple function to quickly convert a datenum to a datetime
% Greg Dusek - 8/21/2017

timeInDatetime=datetime(timeInDatenum,'ConvertFrom','datenum');

end
