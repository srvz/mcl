(in-package :TRAPS)
; Generated from #P"macintosh-hd:hd3:CInterface Translator:Source Interfaces:dlil.h"
; at Sunday July 2,2006 7:27:41 pm.
; 
;  * Copyright (c) 2000 Apple Computer, Inc. All rights reserved.
;  *
;  * @APPLE_LICENSE_HEADER_START@
;  * 
;  * The contents of this file constitute Original Code as defined in and
;  * are subject to the Apple Public Source License Version 1.1 (the
;  * "License").  You may not use this file except in compliance with the
;  * License.  Please obtain a copy of the License at
;  * http://www.apple.com/publicsource and read it before using this file.
;  * 
;  * This Original Code and all software distributed under the License are
;  * distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY KIND, EITHER
;  * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
;  * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
;  * FITNESS FOR A PARTICULAR PURPOSE OR NON-INFRINGEMENT.  Please see the
;  * License for the specific language governing rights and limitations
;  * under the License.
;  * 
;  * @APPLE_LICENSE_HEADER_END@
;  
; 
;  *	Copyright (c) 1999 Apple Computer, Inc. 
;  *
;  *	Data Link Inteface Layer
;  *	Author: Ted Walker
;  
; #ifndef DLIL_H
; #define DLIL_H

(require-interface "sys/appleapiopts")

; #if __STDC__
#| 
 |#

; #endif

; #ifdef __APPLE_API_UNSTABLE
#| #|
#define DLIL_LAST_FILTER   -1
#define DLIL_NULL_FILTER   -2

#define DLIL_WAIT_FOR_FREE -2

#define DLIL_BLUEBOX 1



#include <netif.h>
#include <netif_var.h>
#include <syskern_event.h>

enum {
	BPF_TAP_DISABLE,
	BPF_TAP_INPUT,
	BPF_TAP_OUTPUT,
	BPF_TAP_INPUT_OUTPUT
};


struct dl_tag_attr_str {
    u_long	dl_tag;
    short	if_flags;
    short	if_unit;
    u_long	if_family;
    u_long	protocol_family;
};


struct dlil_pr_flt_str {
    caddr_t	 cookie;

    int	(*filter_dl_input)(caddr_t	cookie, 
			   struct mbuf	**m, 
			   char		**frame_header, 
			   struct ifnet **ifp);


    int (*filter_dl_output)(caddr_t	    cookie, 
			    struct mbuf	    **m, 
			    struct ifnet    **ifp, 
			    struct sockaddr **dest,
			    char            *dest_linkaddr, 
			    char	    *frame_type);

    int (*filter_dl_event)(caddr_t	      cookie, 
			   struct kern_event_msg   *event_msg);

    int (*filter_dl_ioctl)(caddr_t	cookie, 
			   struct ifnet *ifp,
			   u_long	ioctl_cmd,
			   caddr_t	ioctl_arg);

    int	(*filter_detach)(caddr_t  cookie);
    u_long	reserved[2];
};

struct dlil_if_flt_str {
    caddr_t				   cookie;
    int	(*filter_if_input)(caddr_t         cookie,
			   struct ifnet    **ifnet_ptr,
			   struct mbuf     **mbuf_ptr,
			   char		   **frame_ptr);

    int	(*filter_if_event)(caddr_t          cookie,
			   struct ifnet     **ifnet_ptr,
			   struct kern_event_msg **event_msg_ptr);

    int	(*filter_if_output)(caddr_t      cookie,
			    struct ifnet **ifnet_ptr,
			    struct mbuf  **mbuf_ptr);


    int	(*filter_if_ioctl)(caddr_t       cookie,
			   struct ifnet  *ifnet_ptr,
			   u_long	 ioctl_code_ptr,
			   caddr_t       ioctl_arg_ptr);

    int	(*filter_if_free)(caddr_t      cookie,
			  struct ifnet *ifnet_ptr);

    int	(*filter_detach)(caddr_t  cookie);	
    u_long	reserved[2];
};


#define DLIL_PR_FILTER  1
#define DLIL_IF_FILTER  2



typedef int (*dl_input_func)(struct mbuf *m, char *frame_header,
			     struct ifnet *ifp, u_long  dl_tag, int sync_ok);
typedef int (*dl_pre_output_func)(struct ifnet		*ifp,
				  struct mbuf		**m,
				  struct sockaddr	*dest,
				  caddr_t		route_entry,
				  char			*frame_type,
				  char			*dst_addr,
				  u_long		dl_tag);

typedef int (*dl_event_func)(struct kern_event_msg  *event,
			     u_long            dl_tag);

typedef int (*dl_offer_func)(struct mbuf *m, char *frame_header);
typedef int (*dl_ioctl_func)(u_long	dl_tag,
			     struct ifnet *ifp,
			     u_long	ioctl_cmd,
			     caddr_t	ioctl_arg);



#ifdef__APPLE_API_PRIVATE
struct dlil_filterq_entry {
    TAILQ_ENTRY(dlil_filterq_entry) que;
    u_long	 filter_id;
    int		 type;
    union {
	struct dlil_if_flt_str if_filter;
	struct dlil_pr_flt_str pr_filter;
    } variants;
};
#elsestruct dlil_filterq_entry;
#endif

TAILQ_HEAD(dlil_filterq_head, dlil_filterq_entry);


struct if_proto {
    TAILQ_ENTRY(if_proto)			next;
    u_long					dl_tag;
    struct dlil_filterq_head                    pr_flt_head;
    struct ifnet		*ifp;
    dl_input_func		dl_input;
    dl_pre_output_func		dl_pre_output;
    dl_event_func		dl_event;
    dl_offer_func		dl_offer;
    dl_ioctl_func		dl_ioctl;
    u_long			protocol_family;
    u_long			reserved[4];

};

#ifdef__APPLE_API_PRIVATE
TAILQ_HEAD(dlil_proto_head, if_proto);

struct dlil_tag_list_entry {
    TAILQ_ENTRY(dlil_tag_list_entry) next;
    struct ifnet		   *ifp;
    u_long			   dl_tag;
};
#endif


#ifdef__APPLE_API_OBSOLETE

#define DLIL_DESC_RAW		1
#define DLIL_DESC_802_2		2
#define DLIL_DESC_802_2_SNAP	3

#endif


#define DLIL_DESC_ETYPE2	4
#define DLIL_DESC_SAP		5
#define DLIL_DESC_SNAP		6


struct dlil_demux_desc {
    TAILQ_ENTRY(dlil_demux_desc) next;
    
    int		type;
    u_char	*native_type;
    
    union {
        
        
        struct {
            u_long   proto_id_length; 
            u_char   *proto_id;		  
            u_char   *proto_id_mask;
        } bitmask;
        
        struct {
            u_char   dsap;
            u_char   ssap;
            u_char   control_code;
            u_char   pad;
        } desc_802_2;
        
        struct {
            u_char   dsap;			
            u_char   ssap;			
            u_char   control_code; 	
            u_char   org[3];
            u_short  protocol_type; 
        } desc_802_2_SNAP;
        
        
        u_int32_t	native_type_length;
    } variants;
};

TAILQ_HEAD(ddesc_head_str, dlil_demux_desc);


struct dlil_proto_reg_str {
    struct ddesc_head_str	demux_desc_head;
    u_long			interface_family;
    u_long			protocol_family;
    short			unit_number;
    int				default_proto; 
    dl_input_func		input;
    dl_pre_output_func	pre_output;
    dl_event_func		event;
    dl_offer_func		offer;
    dl_ioctl_func		ioctl;
    u_long			reserved[4];
};


int dlil_attach_interface_filter(struct ifnet		   *ifnet_ptr,
				 struct dlil_if_flt_str    *interface_filter,
				 u_long			   *filter_id,
				 int			   insertion_point);

int
dlil_input(struct ifnet  *ifp, struct mbuf *m_head, struct mbuf *m_tail);

int
dlil_output(u_long		dl_tag,
	    struct mbuf		*m,
	    caddr_t		route,
	    struct sockaddr     *dest,
	    int			raw);


int
dlil_ioctl(u_long	proto_family,
	   struct ifnet	*ifp,
	   u_long	ioctl_code,
	   caddr_t	ioctl_arg);

int
dlil_attach_protocol(struct dlil_proto_reg_str   *proto,
		     u_long		         *dl_tag);

int
dlil_detach_protocol(u_long	dl_tag);

int
dlil_if_attach(struct ifnet	*ifp);

int
dlil_attach_protocol_filter(u_long	            dl_tag,
			    struct dlil_pr_flt_str  *proto_filter,
			    u_long   	            *filter_id,
			    int		            insertion_point);
int
dlil_detach_filter(u_long	filter_id);

struct dlil_ifmod_reg_str {
    int (*add_if)(struct ifnet *ifp);
    int (*del_if)(struct ifnet *ifp);
    int (*add_proto)(struct ddesc_head_str   *demux_desc_head,
		     struct if_proto  *proto, u_long dl_tag);
    int (*del_proto)(struct if_proto  *proto, u_long dl_tag);
    int (*ifmod_ioctl)(struct ifnet *ifp, u_long ioctl_cmd, caddr_t data);
    int	(*shutdown)();
    int (*init_if)(struct ifnet *ifp);
    u_long	reserved[3];
};


int dlil_reg_if_modules(u_long  interface_family,
			struct dlil_ifmod_reg_str  *ifmod_reg);

struct dlil_protomod_reg_str {
    
    int (*attach_proto)(struct ifnet *ifp, u_long *dl_tag);

    
    int (*detach_proto)(struct ifnet *ifp, u_long dl_tag); 

    
    u_long	reserved[4];
};



int dlil_reg_proto_module(u_long protocol_family, u_long interface_family,
			struct dlil_protomod_reg_str  *protomod_reg);



int dlil_dereg_proto_module(u_long protocol_family, u_long interface_family);


int dlil_plumb_protocol(u_long protocol_family, struct ifnet *ifp, u_long *dl_tag);


int dlil_unplumb_protocol(u_long protocol_family, struct ifnet *ifp);

int 
dlil_inject_if_input(struct mbuf *m, char *frame_header, u_long from_id);

int
dlil_inject_pr_input(struct mbuf *m, char *frame_header, u_long from_id);

int
dlil_inject_pr_output(struct mbuf		*m,
		      struct sockaddr		*dest,
		      int			raw, 
		      char			*frame_type,
		      char			*dst_linkaddr,
		      u_long			from_id);

int
dlil_inject_if_output(struct mbuf *m, u_long from_id);

int  
dlil_find_dltag(u_long if_family, short unit, u_long proto_family, u_long *dl_tag);


int
dlil_event(struct ifnet *ifp, struct kern_event_msg *event);

int dlil_dereg_if_modules(u_long interface_family);

int
dlil_if_detach(struct ifnet *ifp);




int dlil_if_acquire(u_long family, void *uniqueid, size_t uniqueid_len, 
			struct ifnet **ifp);
			



void dlil_if_release(struct ifnet *ifp);

#endif
|#
 |#
;  __APPLE_API_UNSTABLE 

; #endif /* DLIL_H */


(provide-interface "dlil")