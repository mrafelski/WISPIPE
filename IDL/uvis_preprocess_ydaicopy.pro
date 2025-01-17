;##############################################################
;# WISPIPE
;# Reduction Pipeline for the WISP program (originally by Hakim Atek)
;# uvis_preprocess deals with preparing the UVIS data for darks and CTE
;# Marc Rafelski 2013
;
;
;
;
;###############################################################
; 

; If you specify /darksonly then it just checks which darks you
; need. Do this before running this in the pipeline to make sure you
; have processed the darks for the field beforehand!

; /nopostflash is for older data before postflash. (for running
; calwf3) : around Oct 29, 2012 before postflash was turned on (http://www.stsci.edu/hst/observatory/crds/SIfileInfo/WFC3/WFC3UVISdarks?no_wrap=true)

; You have to tell it if you want it to do a postflash dark in header

;;;; IF RUNNING AFTER OCTOBER 2015 - NEED TO MODIFY the check for post-flash dark

; Modified that now nocte still runs calwf3. Need to specify that
; seperately.

pro uvis_preprocess, field, darksonly=darksonly, tiger=tiger, calwf3only=calwf3only, nocte=nocte, nocalwf3=nocalwf3, mp=mp, nopostflash=nopostflash,path0,pathc

;/nocte, /nocalwf3  ==> copy directory only


;droppath="~/Dropbox/IPAC/WISPS/WISPIPE/aXe/" ; for copying files
;path="~/data2/WISPS/aXe/" ; This is where data will end up
;path_data='~/data2/WISPS/data/'+field+"/" ; this is where raw data are
;path_data_uvis='~/data2/WISPS/data/'+field+"/UVIS/"
path = path0+'/aXe/'
path_data = path0+'/data/'+field+"/"
droppath = pathc+'/aXe/'

if not keyword_set(calwf3only) then begin

if not keyword_set(darksonly) then begin
   spawn,'mkdir '+path_data+"UVIS"
   spawn,'mkdir '+path_data+"UVIS_orig"
   spawn,'cp '+droppath+'runcalwf3.py '+ path_data+'UVIS/'
endif

spawn, 'ls -1 '+path_data+'*raw.fits',raw

;cal_ref_uvis, /auto, /smooth, /postflash

len=n_elements(raw)
darkfilearr = strarr(n_elements(raw))
filterlist = strarr(n_elements(raw))
rootarr =  strarr(n_elements(raw))
for i=0,len-1 do begin
  name=raw(i)
  h=headfits(name) 
  filter=strcompress(sxpar(h,'FILTER'),/remove_all)    
  filterlist[i] = filter
  if (filter eq 'F475X' or filter eq 'F600LP' or filter eq 'F606W' or filter eq 'F814W' ) then begin 
     
     ; Store the original dark name for screen output
    dark=strmid(strcompress(sxpar(h,'DARKFILE'),/remove_all),5,13)
    darkfilearr[i] = dark
    if not keyword_set(darksonly) then begin

      ; Make a new name for the dark, and
      ; store it in the header so that
      ; calwf3 uses the new generated dark. 
       newdark = dark    
       prename = strmid(newdark, 0,1)
       ;;;;;; NOTE!!!!!! 
       ;;;;;; IF naming convention changes in WFC3 darks - you may
       ;;;;;; will need  to modify the naming convention for knowing
       ;;;;;; it has postflash darks

 ;      if (prename eq 'x' or prename eq 'y' or prename eq 'z') and newdark ne 'x2819400i_drk' then strput, newdark, 'p', 0 ; this is for the postflash darks
       if (prename eq 'x' or prename eq 'y' or prename eq 'z' or prename eq '0') and newdark ne 'x2819400i_drk' then strput, newdark, 'p', 0 ; this is for the postflash darks
       if newdark eq 'w971325mi_drk' or newdark eq 'w9k1521si_drk' or newdark eq 'wb81559si_drk' or newdark eq 'wb81559ri_drk' then strput, newdark, 'p', 0 ; this is for the few pre 2013 that have pf darks
       strput, newdark, 'a', 1                                ; this is for averaged darks
       
       darkn = 'iref$'+newdark
       sxaddpar, h, 'DARKFILE', darkn
       modfits, name, 0, h
    endif

    root= strmid(name, 17, 9, /reverse_offset)
    rootarr[i] = root

    if not keyword_set(darksonly) then begin
       print,'copying '+root+'_raw.fits'+' to UVIS directory'
       
       ; we copy the raw and save the
       ; original  UVIS_orig/ since will delete the
       ; original after cte correction. This
       ; way the original file still exists

       spawn,'cp -a '+path_data+root+'_raw.fits'+' '+path_data+'UVIS/'
       print,'moving '+root+'_raw.fits'+' to UVIS_orig directory'
       spawn,'mv '+path_data+root+'_raw.fits'+' '+path_data+'UVIS_orig/'
       print,'moving '+root+'_trl.fits'+' to UVIS_orig directory'
       spawn,'mv '+path_data+root+'_trl.fits'+' '+path_data+'UVIS_orig/'
       print,'moving '+root+'_spt.fits'+' to UVIS_orig directory'
       spawn,'mv '+path_data+root+'_spt.fits'+' '+path_data+'UVIS_orig/'
       print,'moving '+root+'_drz.fits'+' to UVIS_orig directory'
       spawn,'mv '+path_data+root+'_drz.fits'+' '+path_data+'UVIS_orig/'
       print,'moving '+root+'_flt_hlet.fits'+' to UVIS_orig directory'
       spawn,'mv '+path_data+root+'_flt_hlet.fits'+' '+path_data+'UVIS_orig/'
       print,'moving '+root+'_flt.fits'+' to UVIS_orig directory'
       spawn,'mv '+path_data+root+'_flt.fits'+' '+path_data+'UVIS_orig/'



    endif

 endif

endfor

; Lets figure out which darks there are
; need to sort first, then use the uniq function on sorted array. That
; gives you the subscripts. 
darkfiles = darkfilearr[sort(darkfilearr)]
diffdark = uniq(darkfiles)

darksneeded = darkfiles[diffdark]
print, '---------------------------------------------------------'
print, 'Make sure you process the following darks:'
print, darksneeded
print, '---------------------------------------------------------'

if not keyword_set(darksonly) and not keyword_set(nocte) then begin



; Now lets CTE correct the data
   whatuvis = where(filterlist eq 'F475X' or filterlist eq 'F600LP' or filterlist eq 'F606W' or filterlist eq 'F814W', numuvis)

   if numuvis gt 0 then begin
      ;uvisfiles = raw[whatuvis]
      uvisfiles = rootarr[whatuvis]+'_raw.fits'

      spawn, 'pwd', currdir
      cd, path_data+'UVIS/'
      

      for idx=0, n_elements(uvisfiles)-1 do begin
         print, 'Running wfc3uv_ctereverse.e on ', uvisfiles[idx]     

         if keyword_set(mp) then begin
            spawn, 'wfc3uv_ctereverse_parallel.e'  + ' ' + uvisfiles[idx]
         endif else begin
            spawn, 'wfc3uv_ctereverse.e'  + ' ' + uvisfiles[idx]
         endelse
      endfor


      
; Now lets remove old raw data, and rename rac data to raw   
;rac==raw cte corrected
      for idx=0, n_elements(uvisfiles)-1 do begin
         
         locrac =STRPOS(uvisfiles[idx], '_raw.fits')
         name = strmid(uvisfiles[idx],0,locrac)
         spawn, 'rm '+name+'_raw.fits'
         spawn, 'mv '+name+'_rac.fits '+ name+'_raw.fits'
         
      endfor
      
      cd, currdir

   
      print, '---------------------------------------------------------'
      print, 'Did you remember to process the following darks?'
      print, darksneeded
      print, '---------------------------------------------------------'
   endif
endif

endif

; Now lets run calwf3 on the new UVIS data.
; This generates the flt files needed for drizzling
if not keyword_set(darksonly) and not keyword_set(nocte) and not keyword_set(nocalwf3) then begin
   spawn,'cp '+droppath+'runcalwf3.py '+ path_data+'UVIS/'
   cd,  path_data+'UVIS/'
   if not keyword_set(nopostflash) then begin
      cal_ref_uvis, /auto, /avg, /postflash
   endif else begin
      cal_ref_uvis, /auto, /avg
   endelse
   spawn, './runcalwf3.py'
endif

end
