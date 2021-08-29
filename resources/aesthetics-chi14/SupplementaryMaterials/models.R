## model building

library(lme4)

## null model with only random effects
nullmodel = lmer(mean_response ~ 1 + (1|website) + (1|participant_id), data=ae6)

## half model without demographics
halfmodel <- lmer(mean_response ~ (I(colorfulnessmodelnew^2) + I(complexitymodel^2) + colorfulnessmodelnew + complexitymodel) + (1|website) + (1|participant_id), data=ae6)                                                                                                                                                                            


## full model 
fullmodel <- lmer(mean_response ~ (country0.x + age.x + education.x + gender.x + web_usage.x) * (I(colorfulnessmodelnew^2) + I(complexitymodel^2) + colorfulnessmodelnew + complexitymodel) + (1|website) + (1|participant_id), data=ae6)                                                                                                                                                                            

## calculate variance of fixed effects
Fixed <- fixef(fullmodel)[2] * fullmodel@X[, 2] + fixef(fullmodel)[3] * fullmodel@X[, 3]
VarF <- var(Fixed)


## calculate variance-covariance matrix, betas and p-values for model
(VarF + VarCorr(fullmodel)$website[1] + VarCorr(fullmodel)$participant_id[1])/(VarF + VarCorr(fullmodel)$website[1] + VarCorr(fullmodel)$participant_id[1] + (attr(VarCorr(fullmodel), "sc")^2))
Vcov <- vcov(fullmodel, useScale = False)
betas <- fixef(fullmodel)
se <- sqrt(diag(Vcov))
zval <- betas / se
pval <- 2*pnorm(abs(zval), lower.tail = FALSE)
## print everything
cbind(betas, se, zval, pval)

## calculate conditional and marginal R^2 (marginal only uses fixed effects)
#Function rsquared.lme requires models to be input as a list (can include fixed-
#effects only models,but not a good idea to mix models of class "mer" with models 
#of class "lme")
rsquared.lme=function(modlist) {
  #Iterate over each model in the list
  do.call(rbind,lapply(modlist,function(i) {
    #For models fit using lm
    if(class(i)=="lm") {
      Rsquared.mat=data.frame(Class=class(i),Marginal=summary(i)$r.squared,
                              Conditional=NA,AIC=AIC(i)) } 
    #For models fit using lme4
    else if(class(i)=="mer" | class(i)=="merMod" | class(i)=="merLmerTest") {
      #Get variance of fixed effects by multiplying coefficients by design matrix
      VarF=var(as.vector(fixef(i) %*% t(i@X))) 
      #Get variance of random effects by extracting variance components
      VarRand=colSums(do.call(rbind,lapply(VarCorr(i),function(j) j[1])))
      #Get residual variance
      VarResid=attr(VarCorr(i),"sc")^2
      #Calculate marginal R-squared (fixed effects/total variance)
      Rm=VarF/(VarF+VarRand+VarResid)
      #Calculate conditional R-squared (fixed effects+random effects/total variance)
      Rc=(VarF+VarRand)/(VarF+VarRand+VarResid)
      #Bind R^2s into a matrix and return with AIC values
      Rsquared.mat=data.frame(Class=class(i),Marginal=Rm,Conditional=Rc,
                              AIC=AIC(update(i,REML=F))) } 
    #For model fit using nlme  
    else if(class(i)=="lme") {
      #Get design matrix of fixed effects from model
      Fmat=model.matrix(eval(i$call$fixed)[-2],i$data)
      #Get variance of fixed effects by multiplying coefficients by design matrix
      VarF=var(as.vector(fixef(i) %*% t(Fmat)))
      #Get variance of random effects by extracting variance components
      VarRand=sum(suppressWarnings(as.numeric(VarCorr(i)[rownames(VarCorr(i))!=
                                                           "Residual",1])),na.rm=T)
      #Get residual variance
      VarResid=as.numeric(VarCorr(i)[rownames(VarCorr(i))=="Residual",1])
      #Calculate marginal R-squared (fixed effects/total variance)
      Rm=VarF/(VarF+VarRand+VarResid)
      #Calculate conditional R-squared (fixed effects+random effects/total variance)
      Rc=(VarF+VarRand)/(VarF+VarRand+VarResid)
      #Bind R^2s into a matrix and return with AIC values
      Rsquared.mat=data.frame(Class=class(i),Marginal=Rm,Conditional=Rc,
                              AIC=AIC(update(i,method="ML")))
    } else { print("Function requires models of class lm, lme, mer, or merMod") 
    } } ) ) }
rsquared.lme(list(nullmodel,halfmodel))